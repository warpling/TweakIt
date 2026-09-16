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
/// ## Reads are cheap, and stay cheap
///
/// Everything storage serves — the modified-key set, pins, recents, and the values themselves —
/// is held in memory and read from there. `UserDefaults` is the durable copy: it's read once per
/// key to warm the cache and written on every change, but it is never consulted on a plain read.
/// That makes ``value(forKey:default:)`` safe to call at frame rate. See <doc:ReadingValues>.
///
/// - Important: **Storage assumes it owns its keys.** Because the caches are write-through, a
///   change made to the backing `UserDefaults` behind storage's back — writing a prefixed key
///   directly, `removePersistentDomain`, a launch argument, or a *second* `TweakStorage` over the
///   same defaults and prefix — will not be seen. Route writes through this instance, or call
///   ``reloadFromDisk()`` afterwards. One `TweakStorage` per prefix per process is the intended
///   shape; `TweakStore` makes you one for free.
///
/// - Note: **Thread safety.** All members are safe to call from any thread; a lock guards the
///   caches. `objectWillChange` is sent from whichever thread made the change, so mutate from the
///   main thread when SwiftUI is observing.
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

    // MARK: - Caches
    //
    // ⚠️ Every one of these is read on the `value(forKey:default:)` path — the hot path for any
    // consumer that reads a tweak per frame. Backing them directly with `UserDefaults` meant a
    // `CFPreferences` lookup per tweak per read, and CFPreferences `os_log`s the value it returns:
    // for the modified-key set, an array of every modified key, stringified in full, thousands of
    // times a second.
    //
    // That was not a slow path, it was a fatal one. It burned enough CPU to make an app
    // unresponsive and then be killed by the watchdog (`0x8BADF00D`), with the crashing stack
    // sitting in `__CFStringCreateImmutableFunnel3` under `_os_log_fmt_flatten_NSCF` — the logging
    // of the array, not the reading of it. Found in Blackbox, 2026-09-10.
    //
    // 1.1.2 cached the three key lists. It missed the second half of the same read: a *modified*
    // key — precisely the key you are actively tuning — still fell through to
    // `defaults.object(forKey:)`, so the hot case kept a CFPreferences lookup, and its os_log, on
    // every read. 1.2.0 caches the values too.
    //
    // UserDefaults stays the source of truth on disk; these are a write-through cache in front of
    // it, sound as long as nothing else writes these keys — see the type's docs.

    /// Guards every cache below. A plain (non-recursive) lock: the public methods take it, do
    /// their work through the `_`-prefixed unlocked helpers, and release it *before* touching
    /// `UserDefaults` or sending `objectWillChange`, so an observer that reads storage
    /// synchronously can't deadlock.
    ///
    /// ⚠️ **Nothing may write `UserDefaults` while this lock is held.** `UserDefaults` posts
    /// `didChangeNotification` SYNCHRONOUSLY, on the writing thread, before the write call
    /// returns. An observer of that notification that reads a tweak lands back in
    /// ``value(forKey:default:)`` and waits on a lock its own caller owns — a self-deadlock that
    /// needs a force quit, from an ordinary toggle. 1.2.0 shipped exactly that: it added the lock
    /// (there was none through 1.1.0, which is why the same re-entrant read had always been
    /// harmless) and kept writing defaults underneath it. Writes are therefore queued into
    /// ``pendingWrites`` and flushed by ``flushPendingWrites()`` once the lock is down.
    ///
    /// Reads of `UserDefaults` are fine under the lock — they notify nobody.
    private let lock = NSLock()

    /// A `UserDefaults` write queued while ``lock`` was held. Keys are already prefixed.
    private enum PendingWrite {
        case set(String, Any)
        case remove(String)
    }

    /// Writes waiting for the lock to come down. Guarded by ``lock``; drained by
    /// ``flushPendingWrites()``.
    private var pendingWrites: [PendingWrite] = []

    private var cachedModifiedKeys: Set<String>?
    private var cachedPinnedKeys: [String]?
    private var cachedRecentKeys: [String]?

    /// Unprefixed key → the object as `UserDefaults` holds it (a `CGFloat` is stored as `Double`).
    /// ``missingValue`` stands in for "tracked as modified, but nothing on disk", so an
    /// inconsistent pair still costs one `UserDefaults` lookup in total rather than one per read.
    private var cachedValues: [String: Any] = [:]

    /// Section prefix → number of modified keys under it, memoized because the panel asks once per
    /// section row *and* once per category header on every render. Dropped whenever
    /// ``modifiedKeys`` changes, which is the only thing that can change an answer.
    private var cachedSectionCounts: [String: Int] = [:]

    /// Sentinel for a key marked modified with no value behind it. `NSNull` can't come out of a
    /// property list, so it can never collide with a real stored value.
    private static let missingValue = NSNull()

    /// Set of keys that have been modified from their defaults.
    public var modifiedKeys: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return _modifiedKeys()
    }

    /// Creates a new TweakStorage backed by the given UserDefaults and key prefix.
    ///
    /// - Parameters:
    ///   - defaults: The UserDefaults instance to persist values in. Defaults to `.standard`.
    ///   - prefix: A string prepended to all storage keys. Defaults to `"TweakIt."`.
    ///
    /// - Important: Two live instances sharing a `defaults` *and* a `prefix` each cache
    ///   independently and will drift apart. Make one and pass it around.
    public init(defaults: UserDefaults = .standard, prefix: String = "TweakIt.") {
        self.defaults = defaults
        self.prefix = prefix
        self.modifiedKeysKey = prefix + "_modifiedKeys"
        self.pinnedKeysKey = prefix + "_pinnedKeys"
        self.recentKeysKey = prefix + "_recentKeys"
    }

    // MARK: - Value Access

    /// Reads a stored value, returning the default if unmodified.
    ///
    /// Served from memory: an unmodified key costs a set lookup, a modified one a set lookup and a
    /// dictionary lookup. No `UserDefaults` access once the key has been read once.
    public func value<T>(forKey key: String, default defaultValue: T) -> T {
        guard TweakIt.isEnabled else { return defaultValue }

        lock.lock()
        let stored: Any? = _modifiedKeys().contains(key) ? _storedObject(forKey: key) : nil
        lock.unlock()

        guard let stored, !(stored is NSNull) else { return defaultValue }
        return Self.coerce(stored, default: defaultValue)
    }

    /// Stores a value, tracking it as modified. If set back to the default, removes the override.
    ///
    /// Writing the value a key already holds is a no-op — no `UserDefaults` write, no
    /// `objectWillChange`. That matters because a slider drag calls this on every tick, and so
    /// does any host that pushes a computed value into a tweak each frame.
    public func setValue<T>(_ value: T, forKey key: String, default defaultValue: T) where T: Equatable {
        guard TweakIt.isEnabled else { return }

        lock.lock()

        // Every edit counts as recent, including one that puts a value back to its default.
        var changed = _noteRecent(key: key)
        let wasModified = _modifiedKeys().contains(key)
        let prefixedKey = prefix + key

        if value == defaultValue {
            // Back to the default — drop the override entirely. There's nothing to drop if there
            // wasn't one, and no reason to touch UserDefaults to find that out.
            if wasModified {
                cachedValues.removeValue(forKey: key)
                pendingWrites.append(.remove(prefixedKey))
                var keys = _modifiedKeys()
                keys.remove(key)
                _setModifiedKeys(keys)
                changed = true
            }
        } else if !wasModified || Self.coerce(_storedObject(forKey: key), default: defaultValue) != value {
            let stored: Any
            if let cgFloat = value as? CGFloat {
                stored = Double(cgFloat)
            } else {
                stored = value
            }
            // Cache first, queue second: the cache is what a re-entrant reader sees, and it must
            // already be right when the flush below lets one in.
            cachedValues[key] = stored
            pendingWrites.append(.set(prefixedKey, stored))

            if !wasModified {
                var keys = _modifiedKeys()
                keys.insert(key)
                _setModifiedKeys(keys)
            }
            changed = true
        }

        lock.unlock()
        flushPendingWrites()

        // One publish per call, whatever changed — an observer that has to rebuild for a value
        // change gains nothing from hearing about the recents reorder separately.
        if changed { objectWillChange.send() }
    }

    // MARK: - Reset

    /// Reset a single tweak to its default value.
    public func reset(key: String) {
        guard TweakIt.isEnabled else { return }

        lock.lock()
        let wasModified = _modifiedKeys().contains(key)
        cachedValues.removeValue(forKey: key)
        pendingWrites.append(.remove(prefix + key))
        if wasModified {
            var keys = _modifiedKeys()
            keys.remove(key)
            _setModifiedKeys(keys)
        }
        lock.unlock()
        flushPendingWrites()

        if wasModified { objectWillChange.send() }
    }

    /// Reset all tweaks in a section (keys starting with sectionPrefix).
    ///
    /// One publish for the whole section, not one per key.
    public func resetSection(_ sectionPrefix: String) {
        guard TweakIt.isEnabled else { return }

        lock.lock()
        var keys = _modifiedKeys()
        let keysToReset = keys.filter { $0.hasPrefix(sectionPrefix) }
        for key in keysToReset {
            cachedValues.removeValue(forKey: key)
            pendingWrites.append(.remove(prefix + key))
            keys.remove(key)
        }
        let changed = _setModifiedKeys(keys)
        lock.unlock()
        flushPendingWrites()

        if changed { objectWillChange.send() }
    }

    /// Reset all tweaks to defaults.
    public func resetAll() {
        guard TweakIt.isEnabled else { return }

        lock.lock()
        let keys = _modifiedKeys()
        for key in keys {
            pendingWrites.append(.remove(prefix + key))
        }
        cachedValues.removeAll()

        var changed = false
        if !keys.isEmpty {
            _setModifiedKeys([])
            changed = true
        }

        // Recents describe what you were just fiddling with; a full reset makes that
        // history meaningless. Pins are a deliberate act and deliberately survive.
        if !_recentKeys().isEmpty {
            _setRecentKeys([])
            changed = true
        }
        lock.unlock()
        flushPendingWrites()

        if changed { objectWillChange.send() }
    }

    /// Drops every cache, so the next access re-reads the backing `UserDefaults`.
    ///
    /// Storage is a write-through cache over `UserDefaults` and assumes it's the only writer of
    /// its prefixed keys. Call this after changing those keys some other way — seeding values from
    /// a config file, `removePersistentDomain`, or handing the same defaults and prefix to a
    /// second `TweakStorage` — and observers are told to re-read.
    ///
    /// Not needed in normal use: every write made through this instance keeps the cache correct.
    public func reloadFromDisk() {
        flushPendingWrites()

        lock.lock()
        cachedModifiedKeys = nil
        cachedPinnedKeys = nil
        cachedRecentKeys = nil
        cachedValues.removeAll()
        cachedSectionCounts.removeAll()
        lock.unlock()

        objectWillChange.send()
    }

    /// Check if a specific key has been modified.
    public func isModified(key: String) -> Bool {
        guard TweakIt.isEnabled else { return false }
        lock.lock()
        defer { lock.unlock() }
        return _modifiedKeys().contains(key)
    }

    /// Check if any key in a section has been modified.
    public func isSectionModified(_ sectionPrefix: String) -> Bool {
        modifiedCount(forSection: sectionPrefix) > 0
    }

    /// Count how many keys in a section have been modified.
    ///
    /// Memoized per section prefix — the panel asks for this once per visible section row and once
    /// per category header, so an un-memoized scan of the modified set cost
    /// `O(sections × modified keys)` on every render.
    public func modifiedCount(forSection sectionPrefix: String) -> Int {
        guard TweakIt.isEnabled else { return 0 }

        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedSectionCounts[sectionPrefix] { return cached }
        let count = _modifiedKeys().lazy.filter { $0.hasPrefix(sectionPrefix) }.count
        cachedSectionCounts[sectionPrefix] = count
        return count
    }

    // MARK: - Pins

    /// Keys the user has pinned for quick access, in the order they were pinned.
    ///
    /// May contain ghost keys — see the note on ``TweakStorage``. Empty when TweakIt is disabled.
    public var pinnedKeys: [String] {
        guard TweakIt.isEnabled else { return [] }
        lock.lock()
        defer { lock.unlock() }
        return _pinnedKeys()
    }

    /// Whether a key is currently pinned.
    public func isPinned(key: String) -> Bool {
        guard TweakIt.isEnabled else { return false }
        lock.lock()
        defer { lock.unlock() }
        return _pinnedKeys().contains(key)
    }

    /// Pins an unpinned key (appending it to the end) or unpins a pinned one.
    ///
    /// Pinning is independent of a tweak's value: a pin survives ``reset(key:)`` and
    /// ``resetAll()``, and pinning never reads or writes the tweak's value.
    public func togglePin(key: String) {
        guard TweakIt.isEnabled else { return }

        lock.lock()
        var keys = _pinnedKeys()
        if let index = keys.firstIndex(of: key) {
            keys.remove(at: index)
        } else {
            keys.append(key)
        }
        let changed = _setPinnedKeys(keys)
        lock.unlock()
        flushPendingWrites()

        if changed { objectWillChange.send() }
    }

    // MARK: - Recents

    /// The most recently edited keys, newest first, capped at ``maxRecentKeys``.
    ///
    /// Updated from ``setValue(_:forKey:default:)`` — every panel edit counts, including one that
    /// puts a value back to its default. Resets don't: ``reset(key:)`` neither adds a key nor
    /// removes one, while ``resetAll()`` clears the whole list.
    ///
    /// May contain ghost keys — see the note on ``TweakStorage``. Empty when TweakIt is disabled.
    public var recentKeys: [String] {
        guard TweakIt.isEnabled else { return [] }
        lock.lock()
        defer { lock.unlock() }
        return _recentKeys()
    }

    /// Drops a key from ``recentKeys``, leaving its value, its pin and the modified set alone.
    ///
    /// The panel calls this when you unpin a row. A pin and a recent edit both float a tweak into
    /// Quick Access, so unpinning a tweak you had also just edited used to leave the row sitting
    /// exactly where it was — the unpin had worked, the row simply had a second reason to be
    /// there, and the gesture read as broken. The tweak comes back the next time you edit it.
    public func forgetRecent(key: String) {
        guard TweakIt.isEnabled else { return }

        lock.lock()
        var keys = _recentKeys()
        var changed = false
        if let index = keys.firstIndex(of: key) {
            keys.remove(at: index)
            changed = _setRecentKeys(keys)
        }
        lock.unlock()
        flushPendingWrites()

        if changed { objectWillChange.send() }
    }

    // MARK: - Deferred Writes

    /// Lands every queued `UserDefaults` write, with ``lock`` down.
    ///
    /// Each write posts `didChangeNotification` synchronously, so an observer can re-enter this
    /// type from inside the loop. That is safe and intended: the lock is free, and the caches
    /// were made correct before the write was queued, so a re-entrant reader sees the new value
    /// rather than the one still on disk. A re-entrant *writer* queues and flushes its own batch;
    /// the snapshot below is drained before any write goes out, so nothing is sent twice.
    private func flushPendingWrites() {
        lock.lock()
        let writes = pendingWrites
        pendingWrites.removeAll()
        lock.unlock()

        guard !writes.isEmpty else { return }
        for write in writes {
            switch write {
            case .set(let key, let value): defaults.set(value, forKey: key)
            case .remove(let key):         defaults.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Unlocked Internals
    //
    // Everything below assumes `lock` is already held, and none of it sends `objectWillChange` —
    // the public method that took the lock does that after releasing it.

    private func _modifiedKeys() -> Set<String> {
        if let cachedModifiedKeys { return cachedModifiedKeys }
        let value = Set(defaults.array(forKey: modifiedKeysKey) as? [String] ?? [])
        cachedModifiedKeys = value
        return value
    }

    /// - Returns: whether the set actually changed.
    @discardableResult
    private func _setModifiedKeys(_ newValue: Set<String>) -> Bool {
        guard newValue != _modifiedKeys() else { return false }
        cachedModifiedKeys = newValue
        // Section counts are derived from this set and nothing else.
        cachedSectionCounts.removeAll()
        pendingWrites.append(.set(modifiedKeysKey, Array(newValue)))
        return true
    }

    private func _pinnedKeys() -> [String] {
        if let cachedPinnedKeys { return cachedPinnedKeys }
        let value = defaults.stringArray(forKey: pinnedKeysKey) ?? []
        cachedPinnedKeys = value
        return value
    }

    @discardableResult
    private func _setPinnedKeys(_ newValue: [String]) -> Bool {
        guard newValue != _pinnedKeys() else { return false }
        cachedPinnedKeys = newValue
        pendingWrites.append(.set(pinnedKeysKey, newValue))
        return true
    }

    private func _recentKeys() -> [String] {
        if let cachedRecentKeys { return cachedRecentKeys }
        let value = defaults.stringArray(forKey: recentKeysKey) ?? []
        cachedRecentKeys = value
        return value
    }

    @discardableResult
    private func _setRecentKeys(_ newValue: [String]) -> Bool {
        guard newValue != _recentKeys() else { return false }
        cachedRecentKeys = newValue
        pendingWrites.append(.set(recentKeysKey, newValue))
        return true
    }

    /// The stored object for a key, reading through to `UserDefaults` only on a cache miss.
    /// Returns ``missingValue`` when the key is tracked as modified but holds nothing.
    private func _storedObject(forKey key: String) -> Any {
        if let cached = cachedValues[key] { return cached }
        let object = defaults.object(forKey: prefix + key) ?? Self.missingValue
        cachedValues[key] = object
        return object
    }

    /// Moves a key to the front of the recents list.
    ///
    /// Called on every `setValue`, which means once per slider tick while dragging — hence the
    /// early return when the key is already newest. Without it a single drag would rewrite
    /// UserDefaults (and publish `objectWillChange`) dozens of times for no change in content.
    ///
    /// - Returns: whether the list actually changed.
    private func _noteRecent(key: String) -> Bool {
        var keys = _recentKeys()
        guard keys.first != key else { return false }

        keys.removeAll { $0 == key }
        keys.insert(key, at: 0)
        if keys.count > Self.maxRecentKeys {
            keys.removeLast(keys.count - Self.maxRecentKeys)
        }
        return _setRecentKeys(keys)
    }

    // MARK: - Coercion

    /// Converts a stored property-list object to the requested type, falling back to the default.
    ///
    /// Values come back from `UserDefaults` as bridged `NSNumber`s, and a `CGFloat` is stored as a
    /// `Double`, so this can't be a plain `as?`.
    private static func coerce<T>(_ stored: Any, default defaultValue: T) -> T {
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
}
