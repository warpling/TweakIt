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
}
