import XCTest
@testable import DevTweaks

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
}
