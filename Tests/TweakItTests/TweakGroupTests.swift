import XCTest
@testable import TweakIt

/// Covers `TweakGroup`, tweak descriptions, and the key-based lookups added in 1.1.0.
final class TweakGroupTests: XCTestCase {

    private func makeStorage() -> TweakStorage {
        let ud = UserDefaults(suiteName: "TweakGroupTests.\(UUID().uuidString)")!
        return TweakStorage(defaults: ud, prefix: "Test.")
    }

    // MARK: - Key Stability (the load-bearing guarantee)

    /// Wrapping a tweak in a `TweakGroup` must not change its storage key. If it did, every
    /// value a consumer has dialled in on device would silently reset the moment they added
    /// a sub-heading to tidy up a long section.
    func testGroupNameIsNotPartOfTheKey() {
        let ungrouped = TweakStore(storage: makeStorage()) {
            TweakCategory("Visual", icon: "eye") {
                TweakSection("Modal Cards") {
                    TweakDefinition("cornerRadius", default: 12.0, range: 0...40)
                }
            }
        }

        let grouped = TweakStore(storage: makeStorage()) {
            TweakCategory("Visual", icon: "eye") {
                TweakSection("Modal Cards") {
                    TweakGroup("Shape") {
                        TweakDefinition("cornerRadius", default: 12.0, range: 0...40)
                    }
                }
            }
        }

        let expected = "Visual.Modal Cards.cornerRadius"
        XCTAssertEqual(ungrouped.categories[0].sections[0].tweaks[0].id, expected)
        XCTAssertEqual(grouped.categories[0].sections[0].tweaks[0].id, expected)
        XCTAssertNotNil(grouped.tweak(forKey: expected))
        XCTAssertNil(grouped.tweak(forKey: "Visual.Modal Cards.Shape.cornerRadius"))
    }

    /// A value written before grouping must still read back after grouping.
    func testValueSurvivesRegrouping() {
        let ud = UserDefaults(suiteName: "TweakGroupTests.\(UUID().uuidString)")!

        let before = TweakStore(storage: TweakStorage(defaults: ud, prefix: "Test.")) {
            TweakCategory("Visual", icon: "eye") {
                TweakSection("Modal Cards") {
                    TweakDefinition("cornerRadius", default: 12.0, range: 0...40)
                }
            }
        }
        before["Visual.Modal Cards.cornerRadius"] = 30.0

        let after = TweakStore(storage: TweakStorage(defaults: ud, prefix: "Test.")) {
            TweakCategory("Visual", icon: "eye") {
                TweakSection("Modal Cards") {
                    TweakGroup("Shape") {
                        TweakDefinition("cornerRadius", default: 12.0, range: 0...40)
                    }
                }
            }
        }
        let value: Double = after["Visual.Modal Cards.cornerRadius"]
        XCTAssertEqual(value, 30.0)
    }

    // MARK: - Grouping

    func testBareTweaksFormOneImplicitUngroupedRun() {
        let store = TweakStore(storage: makeStorage()) {
            TweakCategory("Visual", icon: "eye") {
                TweakSection("Cards") {
                    TweakDefinition("a", default: true)
                    TweakDefinition("b", default: false)
                }
            }
        }
        let section = store.categories[0].sections[0]
        XCTAssertEqual(section.groups.count, 1)
        XCTAssertNil(section.groups[0].name)
        XCTAssertEqual(section.groups[0].tweaks.map(\.name), ["a", "b"])
        XCTAssertEqual(section.tweaks.map(\.name), ["a", "b"])
    }

    func testGroupsFlattenInDeclarationOrder() {
        let store = TweakStore(storage: makeStorage()) {
            TweakCategory("Visual", icon: "eye") {
                TweakSection("Cards") {
                    TweakGroup("Shape") {
                        TweakDefinition("corner", default: 1.0, range: 0...2)
                        TweakDefinition("inset", default: 2.0, range: 0...4)
                    }
                    TweakGroup("Motion") {
                        TweakDefinition("duration", default: 0.3, range: 0...1)
                    }
                }
            }
        }
        let section = store.categories[0].sections[0]
        XCTAssertEqual(section.groups.map(\.name), ["Shape", "Motion"])
        XCTAssertEqual(section.tweaks.map(\.name), ["corner", "inset", "duration"])
        XCTAssertEqual(section.tweaks.map(\.id), [
            "Visual.Cards.corner", "Visual.Cards.inset", "Visual.Cards.duration",
        ])
    }

    /// Bare tweaks interleaved with groups keep their position: each contiguous bare run
    /// becomes its own unnamed group rather than being hoisted to the top or collapsed together.
    func testMixedBareAndGroupedPreservesOrder() {
        let store = TweakStore(storage: makeStorage()) {
            TweakCategory("Visual", icon: "eye") {
                TweakSection("Cards") {
                    TweakDefinition("enabled", default: true)
                    TweakGroup("Shape") {
                        TweakDefinition("corner", default: 1.0, range: 0...2)
                    }
                    TweakDefinition("debugOverlay", default: false)
                    TweakGroup("Motion") {
                        TweakDefinition("duration", default: 0.3, range: 0...1)
                    }
                }
            }
        }
        let section = store.categories[0].sections[0]
        XCTAssertEqual(section.groups.map(\.name), [nil, "Shape", nil, "Motion"])
        XCTAssertEqual(section.groups.map { $0.tweaks.map(\.name) }, [
            ["enabled"], ["corner"], ["debugOverlay"], ["duration"],
        ])
        XCTAssertEqual(section.tweaks.map(\.name), ["enabled", "corner", "debugOverlay", "duration"])
        XCTAssertEqual(Set(section.groups.map(\.id)).count, 4, "Group IDs must be unique within a section")
    }

    func testGroupsSupportControlFlow() {
        let includeExtras = true
        let store = TweakStore(storage: makeStorage()) {
            TweakCategory("Visual", icon: "eye") {
                TweakSection("Cards") {
                    TweakGroup("Shape") {
                        for name in ["a", "b", "c"] {
                            TweakDefinition(name, default: false)
                        }
                    }
                    if includeExtras {
                        TweakGroup("Extras") {
                            TweakDefinition("extra", default: false)
                        }
                    }
                }
            }
        }
        let section = store.categories[0].sections[0]
        XCTAssertEqual(section.groups.map(\.name), ["Shape", "Extras"])
        XCTAssertEqual(section.tweaks.map(\.name), ["a", "b", "c", "extra"])
    }

    func testEmptyGroupIsPreservedButContributesNoTweaks() {
        let store = TweakStore(storage: makeStorage()) {
            TweakCategory("Visual", icon: "eye") {
                TweakSection("Cards") {
                    TweakGroup("Empty") {}
                    TweakDefinition("a", default: true)
                }
            }
        }
        let section = store.categories[0].sections[0]
        XCTAssertEqual(section.groups.map(\.name), ["Empty", nil])
        XCTAssertTrue(section.groups[0].tweaks.isEmpty)
        XCTAssertEqual(section.tweaks.map(\.name), ["a"])
    }

    /// The DSL-level `TweakSection.tweaks` flatten must match the metadata flatten.
    func testSectionDefinitionFlatten() {
        let section = TweakSection("Cards") {
            TweakDefinition("enabled", default: true)
            TweakGroup("Shape") {
                TweakDefinition("corner", default: 1.0, range: 0...2)
            }
        }
        XCTAssertEqual(section.items.count, 2)
        XCTAssertEqual(section.tweaks.map(\.name), ["enabled", "corner"])
    }

    // MARK: - Descriptions

    func testDescriptionsRoundTripIntoMetadata() {
        let store = TweakStore(storage: makeStorage()) {
            TweakCategory("Debug", icon: "ladybug") {
                TweakSection("Sharing") {
                    TweakDefinition("ignoreEngagedFloor", default: false,
                                    description: "Skip the engagement gate")
                    TweakDefinition("threshold", default: 3, description: "Shares before the drip")
                    TweakDefinition("scale", default: CGFloat(1.0), range: 0...2, description: "Card scale")
                    TweakDefinition("env", default: "prod", options: ["prod", "dev"], description: "Backend")
                    TweakDefinition("Reset", action: {}, description: "Wipes the share count")
                    TweakDefinition("undocumented", default: true)
                }
            }
        }
        let tweaks = store.categories[0].sections[0].tweaks
        XCTAssertEqual(tweaks[0].description, "Skip the engagement gate")
        XCTAssertEqual(tweaks[1].description, "Shares before the drip")
        XCTAssertEqual(tweaks[2].description, "Card scale")
        XCTAssertEqual(tweaks[3].description, "Backend")
        XCTAssertEqual(tweaks[4].description, "Wipes the share count")
        XCTAssertNil(tweaks[5].description, "Description is opt-in and defaults to nil")
    }

    func testDescriptionSurvivesGrouping() {
        let store = TweakStore(storage: makeStorage()) {
            TweakCategory("Debug", icon: "ladybug") {
                TweakSection("Sharing") {
                    TweakGroup("Gating") {
                        TweakDefinition("floor", default: 1, description: "Minimum shares")
                    }
                }
            }
        }
        XCTAssertEqual(store.tweak(forKey: "Debug.Sharing.floor")?.description, "Minimum shares")
    }

    // MARK: - Lookups

    private func lookupStore() -> TweakStore {
        TweakStore(storage: makeStorage()) {
            TweakCategory("Visual", icon: "eye") {
                // A section name with a space, and one with a dot — neither is safe to
                // recover by splitting a key on ".".
                TweakSection("Modal Cards") {
                    TweakDefinition("duration", default: 0.46, range: 0.1...2.0)
                }
                TweakSection("v1.2 Flags") {
                    TweakGroup("Rollout") {
                        TweakDefinition("newUI", default: false)
                    }
                }
            }
        }
    }

    func testTweakForKey() {
        let store = lookupStore()
        XCTAssertEqual(store.tweak(forKey: "Visual.Modal Cards.duration")?.name, "duration")
        XCTAssertEqual(store.tweak(forKey: "Visual.v1.2 Flags.newUI")?.name, "newUI")
    }

    func testSectionContainingKeyWithSpacesAndDots() {
        let store = lookupStore()
        XCTAssertEqual(store.section(containing: "Visual.Modal Cards.duration")?.name, "Modal Cards")
        XCTAssertEqual(store.section(containing: "Visual.Modal Cards.duration")?.id, "Visual.Modal Cards")
        XCTAssertEqual(store.section(containing: "Visual.v1.2 Flags.newUI")?.name, "v1.2 Flags")
        XCTAssertEqual(store.section(containing: "Visual.v1.2 Flags.newUI")?.id, "Visual.v1.2 Flags")
    }

    /// Ghost keys — a pin or recent naming a tweak that was renamed or deleted — must resolve
    /// to nil rather than trapping, so the UI can filter them out.
    func testLookupsReturnNilForGhostKeys() {
        let store = lookupStore()
        XCTAssertNil(store.tweak(forKey: "Visual.Modal Cards.deletedTweak"))
        XCTAssertNil(store.section(containing: "Visual.Modal Cards.deletedTweak"))
        XCTAssertNil(store.tweak(forKey: ""))
        XCTAssertNil(store.section(containing: "Visual.Modal Cards"))
    }

    // MARK: - Backwards Compatibility

    /// The flat-tweaks initializer that shipped in 1.0 must still work and now yield a
    /// single unnamed group.
    func testFlatSectionMetadataInitializerWrapsIntoOneUnnamedGroup() {
        let metadata = TweakSectionMetadata(
            id: "Visual.Cards",
            name: "Cards",
            tweaks: [
                TweakMetadata(id: "Visual.Cards.a", name: "a", defaultValue: true),
                TweakMetadata(id: "Visual.Cards.b", name: "b", defaultValue: false),
            ],
            hasMasterToggle: true
        )
        XCTAssertEqual(metadata.groups.count, 1)
        XCTAssertNil(metadata.groups[0].name)
        XCTAssertEqual(metadata.groups[0].tweaks.map(\.name), ["a", "b"])
        XCTAssertEqual(metadata.tweaks.map(\.name), ["a", "b"])
        XCTAssertTrue(metadata.hasMasterToggle)
    }
}
