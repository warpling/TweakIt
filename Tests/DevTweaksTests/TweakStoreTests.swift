import XCTest
@testable import DevTweaks

final class TweakStoreTests: XCTestCase {

    private func makeStore(defaults: UserDefaults? = nil) -> TweakStore {
        let ud = defaults ?? UserDefaults(suiteName: "TweakStoreTests.\(UUID().uuidString)")!
        let storage = TweakStorage(defaults: ud, prefix: "Test.")
        return TweakStore(storage: storage) {
            TweakCategory("Visual", icon: "eye") {
                TweakSection("Animations") {
                    TweakDefinition("duration", default: 0.46, range: 0.1...2.0)
                    TweakDefinition("damping", default: 0.8, range: 0.1...1.0)
                    TweakDefinition("glassButtons", default: true)
                }
                TweakSection("Layout") {
                    TweakDefinition("columns", default: 3)
                    TweakDefinition("spacing", default: CGFloat(8.0), range: 0.0...32.0)
                }
            }
            TweakCategory("Debug", icon: "ladybug") {
                TweakSection("Network") {
                    TweakDefinition("mockMode", default: false)
                    TweakDefinition("endpoint", default: "production", options: ["production", "staging", "local"])
                    TweakDefinition("timeout", default: "30")
                }
                TweakSection("Feature Flags", hasMasterToggle: true) {
                    TweakDefinition("newUI", default: false)
                }
            }
        }
    }

    // MARK: - DSL Parsing

    func testParsesCategories() {
        let store = makeStore()
        XCTAssertEqual(store.categories.count, 2)
        XCTAssertEqual(store.categories[0].name, "Visual")
        XCTAssertEqual(store.categories[0].icon, "eye")
        XCTAssertEqual(store.categories[1].name, "Debug")
        XCTAssertEqual(store.categories[1].icon, "ladybug")
    }

    func testParsesSections() {
        let store = makeStore()
        let visual = store.categories[0]
        XCTAssertEqual(visual.sections.count, 2)
        XCTAssertEqual(visual.sections[0].name, "Animations")
        XCTAssertEqual(visual.sections[1].name, "Layout")
    }

    func testParsesTweaks() {
        let store = makeStore()
        let animations = store.categories[0].sections[0]
        XCTAssertEqual(animations.tweaks.count, 3)
        XCTAssertEqual(animations.tweaks[0].name, "duration")
        XCTAssertEqual(animations.tweaks[1].name, "damping")
        XCTAssertEqual(animations.tweaks[2].name, "glassButtons")
    }

    func testKeyGeneration() {
        let store = makeStore()
        let animations = store.categories[0].sections[0]
        XCTAssertEqual(animations.tweaks[0].id, "Visual.Animations.duration")
        XCTAssertEqual(animations.tweaks[2].id, "Visual.Animations.glassButtons")
    }

    func testSectionID() {
        let store = makeStore()
        XCTAssertEqual(store.categories[0].sections[0].id, "Visual.Animations")
        XCTAssertEqual(store.categories[1].sections[0].id, "Debug.Network")
    }

    func testControlTypeInference() {
        let store = makeStore()
        let animations = store.categories[0].sections[0]
        XCTAssertEqual(animations.tweaks[0].controlType, .slider)   // Double with range
        XCTAssertEqual(animations.tweaks[2].controlType, .toggle)   // Bool

        let layout = store.categories[0].sections[1]
        XCTAssertEqual(layout.tweaks[0].controlType, .stepper)      // Int no range

        let network = store.categories[1].sections[0]
        XCTAssertEqual(network.tweaks[1].controlType, .picker)      // String with options
        XCTAssertEqual(network.tweaks[2].controlType, .text)        // String no options
    }

    func testMasterToggle() {
        let store = makeStore()
        let featureFlags = store.categories[1].sections[1]
        XCTAssertTrue(featureFlags.hasMasterToggle)

        let animations = store.categories[0].sections[0]
        XCTAssertFalse(animations.hasMasterToggle)
    }

    // MARK: - Subscript Access

    func testSubscriptReadsDefault() {
        let store = makeStore()
        let duration: Double = store["Visual.Animations.duration"]
        XCTAssertEqual(duration, 0.46, accuracy: 0.001)
    }

    func testSubscriptWriteAndRead() {
        let store = makeStore()
        store["Visual.Animations.duration"] = 1.0
        let duration: Double = store["Visual.Animations.duration"]
        XCTAssertEqual(duration, 1.0, accuracy: 0.001)
    }

    func testSubscriptBool() {
        let store = makeStore()
        XCTAssertEqual(store["Visual.Animations.glassButtons"] as Bool, true)
        store["Visual.Animations.glassButtons"] = false
        XCTAssertEqual(store["Visual.Animations.glassButtons"] as Bool, false)
    }

    // MARK: - TweakRef

    func testRefReadsDefault() {
        let store = makeStore()
        let ref = store.ref("Visual.Animations.duration", as: Double.self)
        XCTAssertEqual(ref.value, 0.46, accuracy: 0.001)
    }

    func testRefWriteAndRead() {
        let store = makeStore()
        let ref = store.ref("Visual.Animations.duration", as: Double.self)
        ref.value = 1.5
        XCTAssertEqual(ref.value, 1.5, accuracy: 0.001)
    }

    func testRefIsModified() {
        let store = makeStore()
        let ref = store.ref("Visual.Animations.duration", as: Double.self)
        XCTAssertFalse(ref.isModified)
        ref.value = 1.0
        XCTAssertTrue(ref.isModified)
    }

    func testRefReset() {
        let store = makeStore()
        let ref = store.ref("Visual.Animations.duration", as: Double.self)
        ref.value = 1.0
        XCTAssertTrue(ref.isModified)
        ref.reset()
        XCTAssertFalse(ref.isModified)
        XCTAssertEqual(ref.value, 0.46, accuracy: 0.001)
    }

    // MARK: - Section Enabled

    func testSectionEnabled() {
        let store = makeStore()
        XCTAssertFalse(store.isSectionEnabled("Debug.Feature Flags"))
        store.storage.setValue(true, forKey: "Debug.Feature Flags.isEnabled", default: false)
        XCTAssertTrue(store.isSectionEnabled("Debug.Feature Flags"))
    }
}
