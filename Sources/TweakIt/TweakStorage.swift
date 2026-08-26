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
public final class TweakStorage: ObservableObject {

    private let defaults: UserDefaults
    private let prefix: String
    private let modifiedKeysKey: String

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
}
