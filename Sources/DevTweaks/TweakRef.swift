//
//  TweakRef.swift
//  DevTweaks
//
//  Typed reference handle for reading/writing tweak values.
//  In release builds, `.value` returns the default with zero overhead.
//

import Foundation

/// A typed handle to a tweak value stored in a `TweakStore`.
///
/// In debug builds, reads and writes go through `TweakStorage`. In release builds,
/// the getter returns the compile-time default directly, allowing the compiler to
/// inline and constant-fold the value.
///
/// ```swift
/// let duration = store.ref("Visual.Modal Cards.duration", as: CGFloat.self)
/// let d = duration.value     // reads stored override or default
/// duration.value = 0.5       // persists override
/// ```
public final class TweakRef<T: Equatable> {
    private let key: String
    private let defaultValue: T
    private let storage: TweakStorage

    init(key: String, defaultValue: T, storage: TweakStorage) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
    }

    /// The current tweak value. Returns the persisted override in debug, or the default in release.
    public var value: T {
        get {
            #if DEBUG
            return storage.value(forKey: key, default: defaultValue)
            #else
            return defaultValue
            #endif
        }
        set {
            #if DEBUG
            storage.setValue(newValue, forKey: key, default: defaultValue)
            #endif
        }
    }

    /// Whether this tweak has been modified from its default.
    public var isModified: Bool {
        #if DEBUG
        return storage.isModified(key: key)
        #else
        return false
        #endif
    }

    /// Reset this tweak to its default value.
    public func reset() {
        #if DEBUG
        storage.reset(key: key)
        #endif
    }
}
