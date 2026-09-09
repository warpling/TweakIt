//
//  TweakStorage.swift
//  TweakIt
//
//  Central storage for all tweak values using UserDefaults.
//  Tracks which values have been modified from defaults.
//

import Foundation
import Combine

/// Central storage for all tweak values using UserDefaults.
///
/// Manages persistence of tweak values and tracks which have been modified from their defaults.
/// When TweakIt is disabled, storage operations are no-ops — `TweakRef` returns defaults directly.
///
/// Alongside values, storage holds two small pieces of panel state — ``pinnedKeys`` and
/// ``recentKeys``. Both are plain lists of key strings and are never resolved against a
/// `TweakStore`: storage has no idea which keys still have definitions behind them.
///
/// - Important: **Ghost keys.** A key can outlive its definition — rename or delete a tweak and
///   any pin or recent entry naming it stays on disk. Storage deliberately keeps those strings
///   (renaming a tweak back should restore the pin) and never crashes on them, but it also can't
///   tell them apart from live keys. Anything that turns these lists into UI must resolve each key
///   through `TweakStore.tweak(forKey:)` and skip the misses, or it will try to render a row for a
///   tweak that no longer exists.
public final class TweakStorage: ObservableObject {

    /// The maximum number of keys kept in ``recentKeys``. Older entries fall off the end.
    public static let maxRecentKeys = 5

    private let defaults: UserDefaults
    private let prefix: String
    private let modifiedKeysKey: String
    private let pinnedKeysKey: String
    private let recentKeysKey: String

    /// Set of keys that have been modified from their defaults.
    public private(set) var modifiedKeys: Set<String> {
        get {
            guard let array = defaults.array(forKey: modifiedKeysKey) as? [String] else {
                return []
            }
            return Set(array)
        }
        set {
            objectWillChange.send()
            defaults.set(Array(newValue), forKey: modifiedKeysKey)
        }
    }

    /// Creates a new TweakStorage backed by the given UserDefaults and key prefix.
    ///
    /// - Parameters:
    ///   - defaults: The UserDefaults instance to persist values in. Defaults to `.standard`.
    ///   - prefix: A string prepended to all storage keys. Defaults to `"TweakIt."`.
    public init(defaults: UserDefaults = .standard, prefix: String = "TweakIt.") {
        self.defaults = defaults
        self.prefix = prefix
        self.modifiedKeysKey = prefix + "_modifiedKeys"
        self.pinnedKeysKey = prefix + "_pinnedKeys"
        self.recentKeysKey = prefix + "_recentKeys"
    }

    // MARK: - Value Access

    /// Reads a stored value, returning the default if unmodified.
    public func value<T>(forKey key: String, default defaultValue: T) -> T {
        guard TweakIt.isEnabled else { return defaultValue }

        let prefixedKey = prefix + key

        // If not modified, return default
        guard modifiedKeys.contains(key) else {
            return defaultValue
        }

        // Retrieve stored value
        guard let stored = defaults.object(forKey: prefixedKey) else {
            return defaultValue
        }

        // Handle type conversions
        if T.self == Double.self, let value = stored as? Double {
            return value as! T
        } else if T.self == CGFloat.self, let value = stored as? Double {
            return CGFloat(value) as! T
        } else if T.self == Int.self {
            if let value = stored as? Int {
                return value as! T
            } else if let value = stored as? Double {
                return Int(value) as! T
            }
        } else if T.self == Bool.self, let value = stored as? Bool {
            return value as! T
        } else if T.self == String.self, let value = stored as? String {
            return value as! T
        } else if let value = stored as? T {
            return value
        }

        return defaultValue
    }

    /// Stores a value, tracking it as modified. If set back to the default, removes the override.
    public func setValue<T>(_ value: T, forKey key: String, default defaultValue: T) where T: Equatable {
        guard TweakIt.isEnabled else { return }

        noteRecent(key: key)

        let prefixedKey = prefix + key

        // Check if setting back to default
        if value == defaultValue {
            defaults.removeObject(forKey: prefixedKey)
            let keys = modifiedKeys
            if keys.contains(key) {
                var mutableKeys = keys
                mutableKeys.remove(key)
                modifiedKeys = mutableKeys
            }
            return
        }

        // Store the value
        if let cgFloat = value as? CGFloat {
            defaults.set(Double(cgFloat), forKey: prefixedKey)
        } else {
            defaults.set(value, forKey: prefixedKey)
        }

        // Mark as modified (only update if not already tracked)
        let keys = modifiedKeys
        if !keys.contains(key) {
            var mutableKeys = keys
            mutableKeys.insert(key)
            modifiedKeys = mutableKeys
        } else {
            // The modifiedKeys setter (above) publishes for first-time
            // modifications; value-only changes to an already-modified key
            // must publish too, or observers never hear the second change
            // to the same tweak.
            objectWillChange.send()
        }
    }

    // MARK: - Reset

    /// Reset a single tweak to its default value.
    public func reset(key: String) {
        guard TweakIt.isEnabled else { return }

        let prefixedKey = prefix + key
        defaults.removeObject(forKey: prefixedKey)
        var keys = modifiedKeys
        keys.remove(key)
        modifiedKeys = keys
    }

    /// Reset all tweaks in a section (keys starting with sectionPrefix).
    public func resetSection(_ sectionPrefix: String) {
        guard TweakIt.isEnabled else { return }

        let keysToReset = modifiedKeys.filter { $0.hasPrefix(sectionPrefix) }
        for key in keysToReset {
            reset(key: key)
        }
    }

    /// Reset all tweaks to defaults.
    public func resetAll() {
        guard TweakIt.isEnabled else { return }

        for key in modifiedKeys {
            let prefixedKey = prefix + key
            defaults.removeObject(forKey: prefixedKey)
        }
        modifiedKeys = []

        // Recents describe what you were just fiddling with; a full reset makes that
        // history meaningless. Pins are a deliberate act and deliberately survive.
        if !recentKeys.isEmpty {
            recentKeys = []
        }
    }

    /// Check if a specific key has been modified.
    public func isModified(key: String) -> Bool {
        guard TweakIt.isEnabled else { return false }
        return modifiedKeys.contains(key)
    }

    /// Check if any key in a section has been modified.
    public func isSectionModified(_ sectionPrefix: String) -> Bool {
        guard TweakIt.isEnabled else { return false }
        return modifiedKeys.contains { $0.hasPrefix(sectionPrefix) }
    }

    /// Count how many keys in a section have been modified.
    public func modifiedCount(forSection sectionPrefix: String) -> Int {
        guard TweakIt.isEnabled else { return 0 }
        return modifiedKeys.filter { $0.hasPrefix(sectionPrefix) }.count
    }

    // MARK: - Pins

    /// Keys the user has pinned for quick access, in the order they were pinned.
    ///
    /// May contain ghost keys — see the note on ``TweakStorage``. Empty when TweakIt is disabled.
    public private(set) var pinnedKeys: [String] {
        get {
            guard TweakIt.isEnabled else { return [] }
            return defaults.stringArray(forKey: pinnedKeysKey) ?? []
        }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: pinnedKeysKey)
        }
    }

    /// Whether a key is currently pinned.
    public func isPinned(key: String) -> Bool {
        guard TweakIt.isEnabled else { return false }
        return pinnedKeys.contains(key)
    }

    /// Pins an unpinned key (appending it to the end) or unpins a pinned one.
    ///
    /// Pinning is independent of a tweak's value: a pin survives ``reset(key:)`` and
    /// ``resetAll()``, and pinning never reads or writes the tweak's value.
    public func togglePin(key: String) {
        guard TweakIt.isEnabled else { return }

        var keys = pinnedKeys
        if let index = keys.firstIndex(of: key) {
            keys.remove(at: index)
        } else {
            keys.append(key)
        }
        pinnedKeys = keys
    }

    // MARK: - Recents

    /// The most recently edited keys, newest first, capped at ``maxRecentKeys``.
    ///
    /// Updated from ``setValue(_:forKey:default:)`` — every panel edit counts, including one that
    /// puts a value back to its default. Resets don't: ``reset(key:)`` neither adds a key nor
    /// removes one, while ``resetAll()`` clears the whole list.
    ///
    /// May contain ghost keys — see the note on ``TweakStorage``. Empty when TweakIt is disabled.
    public private(set) var recentKeys: [String] {
        get {
            guard TweakIt.isEnabled else { return [] }
            return defaults.stringArray(forKey: recentKeysKey) ?? []
        }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: recentKeysKey)
        }
    }

    /// Moves a key to the front of the recents list.
    ///
    /// Called on every `setValue`, which means once per slider tick while dragging — hence the
    /// early return when the key is already newest. Without it a single drag would rewrite
    /// UserDefaults (and publish `objectWillChange`) dozens of times for no change in content.
    private func noteRecent(key: String) {
        var keys = recentKeys
        guard keys.first != key else { return }

        keys.removeAll { $0 == key }
        keys.insert(key, at: 0)
        if keys.count > Self.maxRecentKeys {
            keys.removeLast(keys.count - Self.maxRecentKeys)
        }
        recentKeys = keys
    }
}
