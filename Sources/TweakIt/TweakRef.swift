//
//  TweakRef.swift
//  TweakIt
//
//  Typed reference handle for reading/writing tweak values.
//  When TweakIt is disabled, `.value` returns the default with zero overhead.
//

import Foundation

/// A typed handle to a tweak value stored in a `TweakStore`.
///
/// When TweakIt is enabled, reads and writes go through `TweakStorage`. When disabled,
/// the getter returns the default directly.
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

    /// The current tweak value. Returns the persisted override when enabled, or the default when disabled.
    ///
    /// Cheap enough to read every frame — the value comes from memory, not `UserDefaults`. Still
    /// hoist it out of an inner loop, and know that writing back a value the tweak already holds
    /// is dropped rather than persisted. See <doc:ReadingValues>.
    public var value: T {
        get {
            guard TweakIt.isEnabled else { return defaultValue }
            return storage.value(forKey: key, default: defaultValue)
        }
        set {
            guard TweakIt.isEnabled else { return }
            storage.setValue(newValue, forKey: key, default: defaultValue)
        }
    }

    /// Whether this tweak has been modified from its default.
    public var isModified: Bool {
        guard TweakIt.isEnabled else { return false }
        return storage.isModified(key: key)
    }

    /// Reset this tweak to its default value.
    public func reset() {
        guard TweakIt.isEnabled else { return }
        storage.reset(key: key)
    }
}
