import XCTest
import Combine
@testable import TweakIt

final class TweakStorageTests: XCTestCase {

    private var storage: TweakStorage!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "TweakStorageTests.\(UUID().uuidString)")!
        storage = TweakStorage(defaults: defaults, prefix: "Test.")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.description)
        defaults = nil
        storage = nil
        super.tearDown()
    }

    // MARK: - Value Access

    func testReturnsDefaultWhenUnmodified() {
        XCTAssertEqual(storage.value(forKey: "key", default: 42), 42)
        XCTAssertEqual(storage.value(forKey: "key", default: true), true)
        XCTAssertEqual(storage.value(forKey: "key", default: "hello"), "hello")
        XCTAssertEqual(storage.value(forKey: "key", default: 3.14), 3.14)
    }

    func testStoresAndRetrievesBool() {
        storage.setValue(true, forKey: "flag", default: false)
        XCTAssertEqual(storage.value(forKey: "flag", default: false), true)
    }

    func testStoresAndRetrievesInt() {
        storage.setValue(99, forKey: "count", default: 0)
        XCTAssertEqual(storage.value(forKey: "count", default: 0), 99)
    }

    func testStoresAndRetrievesDouble() {
        storage.setValue(2.718, forKey: "euler", default: 0.0)
        XCTAssertEqual(storage.value(forKey: "euler", default: 0.0), 2.718, accuracy: 0.001)
    }

    func testStoresAndRetrievesCGFloat() {
        storage.setValue(CGFloat(1.5), forKey: "scale", default: CGFloat(1.0))
        XCTAssertEqual(storage.value(forKey: "scale", default: CGFloat(1.0)), CGFloat(1.5))
    }

    func testStoresAndRetrievesString() {
        storage.setValue("world", forKey: "greeting", default: "hello")
        XCTAssertEqual(storage.value(forKey: "greeting", default: "hello"), "world")
    }

    // MARK: - Modified Tracking

    func testTracksModifiedKeys() {
        XCTAssertFalse(storage.isModified(key: "a"))

        storage.setValue(true, forKey: "a", default: false)
        XCTAssertTrue(storage.isModified(key: "a"))
    }

    func testSettingBackToDefaultRemovesModified() {
        storage.setValue(true, forKey: "a", default: false)
        XCTAssertTrue(storage.isModified(key: "a"))

        storage.setValue(false, forKey: "a", default: false)
        XCTAssertFalse(storage.isModified(key: "a"))
        XCTAssertEqual(storage.value(forKey: "a", default: false), false)
    }

    func testIsSectionModified() {
        storage.setValue(true, forKey: "Cat.Section.flag", default: false)
        XCTAssertTrue(storage.isSectionModified("Cat.Section"))
        XCTAssertFalse(storage.isSectionModified("Other.Section"))
    }

    func testModifiedCountForSection() {
        storage.setValue(1, forKey: "Cat.S.a", default: 0)
        storage.setValue(2, forKey: "Cat.S.b", default: 0)
        storage.setValue(3, forKey: "Cat.S.c", default: 0)
        XCTAssertEqual(storage.modifiedCount(forSection: "Cat.S"), 3)
    }

    // MARK: - Reset

    func testResetSingleKey() {
        storage.setValue(true, forKey: "a", default: false)
        storage.reset(key: "a")
        XCTAssertFalse(storage.isModified(key: "a"))
        XCTAssertEqual(storage.value(forKey: "a", default: false), false)
    }

    func testResetSection() {
        storage.setValue(1, forKey: "S.a", default: 0)
        storage.setValue(2, forKey: "S.b", default: 0)
        storage.setValue(3, forKey: "Other.c", default: 0)

        storage.resetSection("S")
        XCTAssertFalse(storage.isModified(key: "S.a"))
        XCTAssertFalse(storage.isModified(key: "S.b"))
        XCTAssertTrue(storage.isModified(key: "Other.c"))
    }

    func testResetAll() {
        storage.setValue(1, forKey: "a", default: 0)
        storage.setValue(2, forKey: "b", default: 0)
        storage.resetAll()
        XCTAssertTrue(storage.modifiedKeys.isEmpty)
    }

    // MARK: - Recents

    func testRecentsRecordEditsNewestFirst() {
        storage.setValue(1, forKey: "a", default: 0)
        storage.setValue(1, forKey: "b", default: 0)
        storage.setValue(1, forKey: "c", default: 0)
        XCTAssertEqual(storage.recentKeys, ["c", "b", "a"])
    }

    func testRecentsMoveExistingKeyToFront() {
        storage.setValue(1, forKey: "a", default: 0)
        storage.setValue(1, forKey: "b", default: 0)
        storage.setValue(2, forKey: "a", default: 0)
        XCTAssertEqual(storage.recentKeys, ["a", "b"], "A re-edited key moves up; it isn't duplicated")
    }

    func testRecentsCapAtFive() {
        for index in 0..<8 {
            storage.setValue(1, forKey: "k\(index)", default: 0)
        }
        XCTAssertEqual(storage.recentKeys.count, TweakStorage.maxRecentKeys)
        XCTAssertEqual(storage.recentKeys, ["k7", "k6", "k5", "k4", "k3"])
    }

    /// A slider drag calls `setValue` on every tick. Once the key is newest, further ticks
    /// must not touch the recents list at all.
    func testRecentsNoOpWhenKeyIsAlreadyFirst() {
        storage.setValue(1, forKey: "b", default: 0)
        storage.setValue(1, forKey: "a", default: 0)

        var publishCount = 0
        let cancellable = storage.objectWillChange.sink { publishCount += 1 }
        defer { cancellable.cancel() }

        let before = storage.recentKeys
        for value in 2...20 {
            storage.setValue(value, forKey: "a", default: 0)
        }
        XCTAssertEqual(storage.recentKeys, before)
        XCTAssertEqual(publishCount, 19, "One publish per value change, none from recents churn")
    }

    func testSettingBackToDefaultStillCountsAsRecent() {
        storage.setValue(1, forKey: "a", default: 0)
        storage.setValue(1, forKey: "b", default: 0)
        storage.setValue(0, forKey: "a", default: 0)
        XCTAssertEqual(storage.recentKeys, ["a", "b"])
        XCTAssertFalse(storage.isModified(key: "a"))
    }

    func testResetDoesNotTouchRecents() {
        storage.setValue(1, forKey: "a", default: 0)
        storage.setValue(1, forKey: "b", default: 0)
        storage.reset(key: "a")
        XCTAssertEqual(storage.recentKeys, ["b", "a"], "reset neither adds nor removes a recent")
    }

    func testResetAllClearsRecents() {
        storage.setValue(1, forKey: "a", default: 0)
        storage.setValue(1, forKey: "b", default: 0)
        storage.resetAll()
        XCTAssertTrue(storage.recentKeys.isEmpty)
    }

    func testRecentsPersistAcrossStorageInstances() {
        storage.setValue(1, forKey: "a", default: 0)
        let reloaded = TweakStorage(defaults: defaults, prefix: "Test.")
        XCTAssertEqual(reloaded.recentKeys, ["a"])
    }

    // MARK: - Pins

    func testTogglePinRoundTrip() {
        XCTAssertFalse(storage.isPinned(key: "a"))
        storage.togglePin(key: "a")
        XCTAssertTrue(storage.isPinned(key: "a"))
        storage.togglePin(key: "a")
        XCTAssertFalse(storage.isPinned(key: "a"))
        XCTAssertTrue(storage.pinnedKeys.isEmpty)
    }

    func testPinsKeepPinOrder() {
        storage.togglePin(key: "c")
        storage.togglePin(key: "a")
        storage.togglePin(key: "b")
        XCTAssertEqual(storage.pinnedKeys, ["c", "a", "b"])

        storage.togglePin(key: "a")
        XCTAssertEqual(storage.pinnedKeys, ["c", "b"])

        storage.togglePin(key: "a")
        XCTAssertEqual(storage.pinnedKeys, ["c", "b", "a"], "Re-pinning appends to the end")
    }

    func testPinsSurviveResetAll() {
        storage.togglePin(key: "a")
        storage.setValue(1, forKey: "a", default: 0)
        storage.resetAll()
        XCTAssertEqual(storage.pinnedKeys, ["a"], "A pin is deliberate; a reset of values shouldn't drop it")
        XCTAssertFalse(storage.isModified(key: "a"))
    }

    func testPinsAreIndependentOfValues() {
        storage.togglePin(key: "a")
        storage.setValue(1, forKey: "a", default: 0)
        storage.reset(key: "a")
        XCTAssertTrue(storage.isPinned(key: "a"))
    }

    func testPinsPersistAcrossStorageInstances() {
        storage.togglePin(key: "a")
        let reloaded = TweakStorage(defaults: defaults, prefix: "Test.")
        XCTAssertEqual(reloaded.pinnedKeys, ["a"])
    }

    /// Storage stores raw key strings and never resolves them, so a pin naming a tweak that
    /// no longer exists is stored and returned without complaint. Filtering is the UI's job.
    func testGhostKeysAreStoredWithoutResolution() {
        storage.togglePin(key: "Gone.Section.tweak")
        storage.setValue(1, forKey: "Gone.Section.tweak", default: 0)
        XCTAssertEqual(storage.pinnedKeys, ["Gone.Section.tweak"])
        XCTAssertEqual(storage.recentKeys, ["Gone.Section.tweak"])
    }

    // MARK: - Disabled

    func testPinsAndRecentsAreInertWhenDisabled() {
        TweakIt.isEnabled = false
        defer { TweakIt.isEnabled = true }

        storage.togglePin(key: "a")
        storage.setValue(1, forKey: "a", default: 0)
        XCTAssertTrue(storage.pinnedKeys.isEmpty)
        XCTAssertTrue(storage.recentKeys.isEmpty)
        XCTAssertFalse(storage.isPinned(key: "a"))
    }

    // MARK: - Caching (hot path)
    //
    // The bug these guard against: `value(forKey:default:)` reaching UserDefaults on every call.
    // A consumer reading a tweak per frame then paid a CFPreferences lookup per read, and
    // CFPreferences os_logs what it returns — enough string building to hang an app until the
    // watchdog killed it. Reads must be served from memory.

    func testReadsDoNotTouchUserDefaultsOnceWarm() {
        let counting = CountingUserDefaults(suiteName: "TweakStorageTests.\(UUID().uuidString)")!
        defer { counting.removePersistentDomain(forName: counting.description) }
        let storage = TweakStorage(defaults: counting, prefix: "Test.")

        storage.setValue(0.5, forKey: "modified", default: 0.0)
        _ = storage.value(forKey: "modified", default: 0.0)
        _ = storage.value(forKey: "untouched", default: 0.0)

        let readsAfterWarmUp = counting.readCount
        for _ in 0..<1_000 {
            _ = storage.value(forKey: "modified", default: 0.0)
            _ = storage.value(forKey: "untouched", default: 0.0)
        }

        XCTAssertEqual(counting.readCount, readsAfterWarmUp,
                       "2000 reads must not reach UserDefaults even once")
    }

    func testKeyListsAreLoadedFromUserDefaultsOnlyOnce() {
        let counting = CountingUserDefaults(suiteName: "TweakStorageTests.\(UUID().uuidString)")!
        defer { counting.removePersistentDomain(forName: counting.description) }
        let storage = TweakStorage(defaults: counting, prefix: "Test.")

        _ = storage.modifiedKeys
        _ = storage.pinnedKeys
        _ = storage.recentKeys

        // Three lists, one load each. `NSUserDefaults` funnels `array`/`stringArray` through
        // `object(forKey:)`, so the counter sees each load twice — hence the bound rather than 3.
        let readsAfterWarmUp = counting.readCount
        XCTAssertLessThanOrEqual(readsAfterWarmUp, 6)

        for _ in 0..<50 {
            _ = storage.modifiedKeys
            _ = storage.isModified(key: "a")
            _ = storage.pinnedKeys
            _ = storage.recentKeys
            _ = storage.isPinned(key: "a")
        }
        XCTAssertEqual(counting.readCount, readsAfterWarmUp, "The lists must never be re-read")
    }

    func testWritesKeepTheCacheCorrect() {
        storage.setValue(1.5, forKey: "a", default: 0.0)
        XCTAssertEqual(storage.value(forKey: "a", default: 0.0), 1.5)

        storage.setValue(2.5, forKey: "a", default: 0.0)
        XCTAssertEqual(storage.value(forKey: "a", default: 0.0), 2.5, "A second write must not serve the first value")

        storage.setValue(CGFloat(3.5), forKey: "cg", default: CGFloat(0))
        XCTAssertEqual(storage.value(forKey: "cg", default: CGFloat(0)), CGFloat(3.5))
        XCTAssertEqual(storage.value(forKey: "cg", default: CGFloat(0)), CGFloat(3.5), "Cached CGFloat still coerces from its stored Double")
    }

    func testResetEvictsTheCachedValue() {
        storage.setValue(7, forKey: "a", default: 0)
        XCTAssertEqual(storage.value(forKey: "a", default: 0), 7)

        storage.reset(key: "a")
        XCTAssertEqual(storage.value(forKey: "a", default: 0), 0, "A reset key must not serve its old value")

        storage.setValue(9, forKey: "a", default: 0)
        XCTAssertEqual(storage.value(forKey: "a", default: 0), 9)
    }

    func testResetAllEvictsCachedValues() {
        storage.setValue(7, forKey: "a", default: 0)
        storage.setValue(8, forKey: "b", default: 0)
        _ = storage.value(forKey: "a", default: 0)
        _ = storage.value(forKey: "b", default: 0)

        storage.resetAll()
        XCTAssertEqual(storage.value(forKey: "a", default: 0), 0)
        XCTAssertEqual(storage.value(forKey: "b", default: 0), 0)
    }

    /// Storage owns its keys. This pins the documented consequence — and the way out of it.
    func testReloadFromDiskPicksUpAnExternalWrite() {
        storage.setValue(1, forKey: "a", default: 0)
        XCTAssertEqual(storage.value(forKey: "a", default: 0), 1)

        defaults.set(42, forKey: "Test.a")
        XCTAssertEqual(storage.value(forKey: "a", default: 0), 1,
                       "A write behind storage's back is invisible — that's the documented contract")

        storage.reloadFromDisk()
        XCTAssertEqual(storage.value(forKey: "a", default: 0), 42, "reloadFromDisk is the way back")
    }

    func testReloadFromDiskPicksUpAnExternallyClearedDomain() {
        storage.setValue(1, forKey: "a", default: 0)
        storage.togglePin(key: "a")

        defaults.removeObject(forKey: "Test._modifiedKeys")
        defaults.removeObject(forKey: "Test._pinnedKeys")
        defaults.removeObject(forKey: "Test.a")
        storage.reloadFromDisk()

        XCTAssertEqual(storage.value(forKey: "a", default: 0), 0)
        XCTAssertTrue(storage.modifiedKeys.isEmpty)
        XCTAssertTrue(storage.pinnedKeys.isEmpty)
    }

    // MARK: - Write Amplification

    /// A host that pushes a computed value into a tweak every frame — or a slider that redelivers
    /// the value it already holds — must not write to UserDefaults or invalidate every observer.
    func testRewritingTheSameValueIsANoOp() {
        let counting = CountingUserDefaults(suiteName: "TweakStorageTests.\(UUID().uuidString)")!
        defer { counting.removePersistentDomain(forName: counting.description) }
        let storage = TweakStorage(defaults: counting, prefix: "Test.")

        storage.setValue(0.5, forKey: "a", default: 0.0)

        var publishCount = 0
        let cancellable = storage.objectWillChange.sink { publishCount += 1 }
        defer { cancellable.cancel() }
        let writesBefore = counting.writeCount

        for _ in 0..<60 {
            storage.setValue(0.5, forKey: "a", default: 0.0)
        }

        XCTAssertEqual(publishCount, 0, "An unchanged value must not publish")
        XCTAssertEqual(counting.writeCount, writesBefore, "An unchanged value must not write")
        XCTAssertEqual(storage.value(forKey: "a", default: 0.0), 0.5)
    }

    /// Setting an untouched key to its own default has nothing to clear.
    func testSettingAnUnmodifiedKeyToItsDefaultIsANoOp() {
        let counting = CountingUserDefaults(suiteName: "TweakStorageTests.\(UUID().uuidString)")!
        defer { counting.removePersistentDomain(forName: counting.description) }
        let storage = TweakStorage(defaults: counting, prefix: "Test.")

        storage.setValue(0, forKey: "a", default: 0)
        let writesAfterFirst = counting.writeCount
        storage.setValue(0, forKey: "a", default: 0)

        XCTAssertEqual(counting.writeCount, writesAfterFirst,
                       "Only the recents bookkeeping should ever have written")
        XCTAssertFalse(storage.isModified(key: "a"))
    }

    /// One `setValue`, one publish — even when it both moves recents and changes a value.
    func testEachChangingSetValuePublishesExactlyOnce() {
        storage.setValue(1, forKey: "a", default: 0)
        storage.setValue(1, forKey: "b", default: 0)

        var publishCount = 0
        let cancellable = storage.objectWillChange.sink { publishCount += 1 }
        defer { cancellable.cancel() }

        storage.setValue(2, forKey: "a", default: 0)   // moves recents AND changes the value
        XCTAssertEqual(publishCount, 1)

        storage.setValue(3, forKey: "a", default: 0)   // value only
        XCTAssertEqual(publishCount, 2)

        storage.setValue(0, forKey: "a", default: 0)   // back to default
        XCTAssertEqual(publishCount, 3)
    }

    /// The panel's per-section Reset button clears many keys at once; observers should hear
    /// about it once, not once per key.
    func testResetSectionPublishesOnce() {
        storage.setValue(1, forKey: "S.a", default: 0)
        storage.setValue(2, forKey: "S.b", default: 0)
        storage.setValue(3, forKey: "S.c", default: 0)
        storage.setValue(4, forKey: "Other.d", default: 0)

        var publishCount = 0
        let cancellable = storage.objectWillChange.sink { publishCount += 1 }
        defer { cancellable.cancel() }

        storage.resetSection("S")
        XCTAssertEqual(publishCount, 1)
        XCTAssertEqual(storage.modifiedKeys, ["Other.d"])
        XCTAssertEqual(storage.value(forKey: "S.a", default: 0), 0, "A reset key must not serve its old value")

        storage.resetSection("S")
        XCTAssertEqual(publishCount, 1, "Resetting an already-clean section publishes nothing")
    }

    // MARK: - Section Counts

    func testSectionCountsFollowModifications() {
        XCTAssertEqual(storage.modifiedCount(forSection: "S"), 0)

        storage.setValue(1, forKey: "S.a", default: 0)
        XCTAssertEqual(storage.modifiedCount(forSection: "S"), 1, "A memoized count must not outlive the change that invalidates it")
        XCTAssertTrue(storage.isSectionModified("S"))

        storage.setValue(1, forKey: "S.b", default: 0)
        XCTAssertEqual(storage.modifiedCount(forSection: "S"), 2)

        storage.reset(key: "S.a")
        XCTAssertEqual(storage.modifiedCount(forSection: "S"), 1)

        storage.resetAll()
        XCTAssertEqual(storage.modifiedCount(forSection: "S"), 0)
        XCTAssertFalse(storage.isSectionModified("S"))
    }

    /// Re-editing an already-modified key doesn't change the count, and mustn't drop the memo
    /// into a wrong answer either.
    func testSectionCountIsStableAcrossValueOnlyEdits() {
        storage.setValue(1, forKey: "S.a", default: 0)
        for value in 2...20 {
            storage.setValue(value, forKey: "S.a", default: 0)
            XCTAssertEqual(storage.modifiedCount(forSection: "S"), 1)
        }
    }

    // MARK: - Concurrency

    /// Caching turned every read into a mutation of shared state. Reading a tweak off the main
    /// thread is a normal thing for a host to do, so the caches have to be locked.
    // MARK: - Re-entrancy

    // `UserDefaults` posts `didChangeNotification` SYNCHRONOUSLY on the writing thread, so an
    // observer of it runs INSIDE the write that triggered it. If that observer reads a tweak — a
    // debug overlay mirroring a toggle, say — it re-enters this type. 1.2.0 added the lock and
    // kept writing defaults underneath it, so the re-entrant read waited on a lock its own caller
    // held and the app hung hard, on every toggle, needing a force quit. Found in Blackbox,
    // 2026-09-11.
    //
    // These tests deadlock rather than fail when the invariant breaks, hence the watchdog: the
    // write runs on a background queue and the test fails if it hasn't returned in time.

    /// Runs `body` off the main thread and fails if it doesn't return within `timeout`.
    private func expectNoDeadlock(timeout: TimeInterval = 5,
                                  _ message: String,
                                  _ body: @escaping () -> Void) {
        let finished = expectation(description: message)
        DispatchQueue.global().async {
            body()
            finished.fulfill()
        }
        wait(for: [finished], timeout: timeout)
    }

    func testWritingDoesNotDeadlockAnObserverThatReadsBack() {
        var observed: Int?
        let token = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: nil
        ) { [storage] _ in
            // The re-entrant read. Must not wait on the writer's lock.
            observed = storage?.value(forKey: "reentrant", default: 0)
        }
        defer { NotificationCenter.default.removeObserver(token) }

        expectNoDeadlock("setValue with a re-entrant reader") {
            self.storage.setValue(7, forKey: "reentrant", default: 0)
        }

        XCTAssertEqual(storage.value(forKey: "reentrant", default: 0), 7)
        // The observer ran inside the write and must have seen the NEW value: caches are made
        // correct before a write is queued, precisely so a re-entrant reader isn't served the
        // value still sitting on disk.
        XCTAssertEqual(observed, 7, "a re-entrant reader saw a stale value")
    }

    func testResettingDoesNotDeadlockAnObserverThatReadsBack() {
        storage.setValue(7, forKey: "reentrant", default: 0)

        let token = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: nil
        ) { [storage] _ in
            _ = storage?.value(forKey: "reentrant", default: 0)
            _ = storage?.isModified(key: "reentrant")
        }
        defer { NotificationCenter.default.removeObserver(token) }

        expectNoDeadlock("reset with a re-entrant reader") {
            self.storage.reset(key: "reentrant")
        }
        expectNoDeadlock("resetAll with a re-entrant reader") {
            self.storage.setValue(9, forKey: "reentrant", default: 0)
            self.storage.resetAll()
        }
        expectNoDeadlock("togglePin with a re-entrant reader") {
            self.storage.togglePin(key: "reentrant")
        }

        XCTAssertEqual(storage.value(forKey: "reentrant", default: 0), 0)
    }

    /// An observer that WRITES from inside the notification — the nastiest shape, because its
    /// write queues and flushes its own batch while the outer flush is still draining.
    func testWritingFromInsideTheNotificationDoesNotDeadlockOrLoseWrites() {
        var reentered = false
        let token = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: nil
        ) { [storage] _ in
            guard !reentered else { return }   // one hop, or this recurses forever by design
            reentered = true
            storage?.setValue("inner", forKey: "written.by.observer", default: "")
        }
        defer { NotificationCenter.default.removeObserver(token) }

        expectNoDeadlock("setValue with a re-entrant writer") {
            self.storage.setValue("outer", forKey: "written.by.caller", default: "")
        }

        XCTAssertEqual(storage.value(forKey: "written.by.caller", default: ""), "outer")
        XCTAssertEqual(storage.value(forKey: "written.by.observer", default: ""), "inner")
    }

    func testConcurrentReadsAndWritesDoNotCorruptState() {
        storage.setValue(1, forKey: "shared", default: 0)

        DispatchQueue.concurrentPerform(iterations: 200) { iteration in
            if iteration % 4 == 0 {
                storage.setValue(iteration + 1, forKey: "shared", default: 0)
                storage.togglePin(key: "pin.\(iteration)")
            } else {
                _ = storage.value(forKey: "shared", default: 0)
                _ = storage.value(forKey: "never.set", default: 7)
                _ = storage.isSectionModified("shared")
                _ = storage.recentKeys
                _ = storage.pinnedKeys
            }
        }

        XCTAssertTrue(storage.isModified(key: "shared"))
        XCTAssertEqual(storage.value(forKey: "never.set", default: 7), 7)
    }
}

// MARK: - Counting UserDefaults

/// A `UserDefaults` that counts the calls `TweakStorage` makes to it, so a test can assert that
/// a read never reaches the store's backing preferences.
private final class CountingUserDefaults: UserDefaults {
    private(set) var readCount = 0
    private(set) var writeCount = 0

    override func object(forKey defaultName: String) -> Any? {
        readCount += 1
        return super.object(forKey: defaultName)
    }

    override func array(forKey defaultName: String) -> [Any]? {
        readCount += 1
        return super.array(forKey: defaultName)
    }

    override func stringArray(forKey defaultName: String) -> [String]? {
        readCount += 1
        return super.stringArray(forKey: defaultName)
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        writeCount += 1
        super.set(value, forKey: defaultName)
    }

    override func removeObject(forKey defaultName: String) {
        writeCount += 1
        super.removeObject(forKey: defaultName)
    }
}

