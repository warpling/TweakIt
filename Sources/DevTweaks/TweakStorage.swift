//
//  TweakStorage.swift
//  DevTweaks
//
//  Central storage for all tweak values using UserDefaults.
//  Tracks which values have been modified from defaults.
//

import Foundation
import Combine

/// Central storage for all tweak values using UserDefaults.
///
/// Manages persistence of tweak values and tracks which have been modified from their defaults.
/// In release builds, storage operations are no-ops — `TweakRef` returns defaults directly.
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
    ///   - prefix: A string prepended to all storage keys. Defaults to `"DevTweaks."`.
    public init(defaults: UserDefaults = .standard, prefix: String = "DevTweaks.") {
        self.defaults = defaults
        self.prefix = prefix
        self.modifiedKeysKey = prefix + "_modifiedKeys"
    }

    // MARK: - Value Access

    /// Reads a stored value, returning the default if unmodified.
    public func value<T>(forKey key: String, default defaultValue: T) -> T {
        #if DEBUG
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
        #else
        return defaultValue
        #endif
    }

    /// Stores a value, tracking it as modified. If set back to the default, removes the override.
    public func setValue<T>(_ value: T, forKey key: String, default defaultValue: T) where T: Equatable {
        #if DEBUG
        let prefixedKey = prefix + key

        // Check if setting back to default
        if value == defaultValue {
            defaults.removeObject(forKey: prefixedKey)
            var keys = modifiedKeys
            keys.remove(key)
            modifiedKeys = keys
            return
        }

        // Store the value
        if let cgFloat = value as? CGFloat {
            defaults.set(Double(cgFloat), forKey: prefixedKey)
        } else {
            defaults.set(value, forKey: prefixedKey)
        }

        // Mark as modified
        var keys = modifiedKeys
        keys.insert(key)
        modifiedKeys = keys
        #endif
    }

    // MARK: - Reset

    /// Reset a single tweak to its default value.
    public func reset(key: String) {
        #if DEBUG
        let prefixedKey = prefix + key
        defaults.removeObject(forKey: prefixedKey)
        var keys = modifiedKeys
        keys.remove(key)
        modifiedKeys = keys
        #endif
    }

    /// Reset all tweaks in a section (keys starting with sectionPrefix).
    public func resetSection(_ sectionPrefix: String) {
        #if DEBUG
        let keysToReset = modifiedKeys.filter { $0.hasPrefix(sectionPrefix) }
        for key in keysToReset {
            reset(key: key)
        }
        #endif
    }

    /// Reset all tweaks to defaults.
    public func resetAll() {
        #if DEBUG
        for key in modifiedKeys {
            let prefixedKey = prefix + key
            defaults.removeObject(forKey: prefixedKey)
        }
        modifiedKeys = []
        #endif
    }

    /// Check if a specific key has been modified.
    public func isModified(key: String) -> Bool {
        #if DEBUG
        return modifiedKeys.contains(key)
        #else
        return false
        #endif
    }

    /// Check if any key in a section has been modified.
    public func isSectionModified(_ sectionPrefix: String) -> Bool {
        #if DEBUG
        return modifiedKeys.contains { $0.hasPrefix(sectionPrefix) }
        #else
        return false
        #endif
    }

    /// Count how many keys in a section have been modified.
    public func modifiedCount(forSection sectionPrefix: String) -> Int {
        #if DEBUG
        return modifiedKeys.filter { $0.hasPrefix(sectionPrefix) }.count
        #else
        return 0
        #endif
    }
}
