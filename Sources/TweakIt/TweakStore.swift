//
//  TweakStore.swift
//  TweakIt
//
//  Central store built from a result builder DSL.
//  Provides subscript access, TweakRef factory, and category metadata for the UI.
//

import Foundation
import SwiftUI

/// Central store for all tweaks defined via the result builder DSL.
///
/// Define tweaks once; the store provides type-safe access, persistence, and UI metadata:
///
/// ```swift
/// let store = TweakStore {
///     TweakCategory("Visual", icon: "eye") {
///         TweakSection("Modal Cards") {
///             TweakDefinition("duration", default: 0.46, range: 0.1...2.0)
///             TweakDefinition("glassButtons", default: true)
///         }
///     }
/// }
/// ```
public final class TweakStore {

    /// The underlying storage engine.
    public let storage: TweakStorage

    /// Parsed category metadata for UI rendering.
    public let categories: [TweakCategoryMetadata]

    /// Lookup table: full key path → TweakMetadata.
    private let tweaksByKey: [String: TweakMetadata]

    /// Lookup table: full key path → the section metadata that owns it.
    ///
    /// Built during `init` rather than derived by splitting the key: section and category
    /// names may contain dots and spaces ("Modal Cards", "v1.2 Flags"), so a key is not
    /// structurally parseable back into its parts.
    private let sectionsByKey: [String: TweakSectionMetadata]

    /// Lookup table: full key path → default value (typed as Any).
    private let defaultsByKey: [String: Any]

    /// Creates a store from a result builder DSL definition.
    ///
    /// - Parameters:
    ///   - storage: The storage engine. Defaults to a new `TweakStorage()`.
    ///   - categories: A result builder closure returning `TweakCategory` definitions.
    public init(
        storage: TweakStorage = TweakStorage(),
        @TweakCategoryBuilder categories: () -> [TweakCategory]
    ) {
        self.storage = storage
        let defs = categories()
        var allTweaks = [String: TweakMetadata]()
        var allDefaults = [String: Any]()
        var allSections = [String: TweakSectionMetadata]()
        var builtCategories = [TweakCategoryMetadata]()

        /// Builds one tweak's metadata. The group a tweak was declared in deliberately
        /// plays no part in its key — see `TweakGroup`.
        func makeMetadata(_ tweak: TweakDefinition, sectionPrefix: String) -> TweakMetadata {
            let key = "\(sectionPrefix).\(tweak.name)"
            let metadata: TweakMetadata
            if let action = tweak.action {
                metadata = TweakMetadata(id: key, name: tweak.name, action: action, description: tweak.description)
            } else {
                metadata = TweakMetadata(
                    id: key,
                    name: tweak.name,
                    defaultValue: tweak.defaultValue,
                    range: tweak.range,
                    options: tweak.options,
                    description: tweak.description
                )
            }
            allTweaks[key] = metadata
            allDefaults[key] = tweak.defaultValue
            return metadata
        }

        for category in defs {
            var builtSections = [TweakSectionMetadata]()

            for section in category.sections {
                let sectionPrefix = "\(category.name).\(section.name)"
                var builtGroups = [TweakGroupMetadata]()
                var pendingUngrouped = [TweakMetadata]()

                func flushUngrouped() {
                    guard !pendingUngrouped.isEmpty else { return }
                    builtGroups.append(TweakGroupMetadata(
                        id: "\(sectionPrefix)#\(builtGroups.count)",
                        name: nil,
                        tweaks: pendingUngrouped
                    ))
                    pendingUngrouped = []
                }

                for item in section.items {
                    switch item {
                    case .tweak(let tweak):
                        pendingUngrouped.append(makeMetadata(tweak, sectionPrefix: sectionPrefix))
                    case .group(let group):
                        flushUngrouped()
                        builtGroups.append(TweakGroupMetadata(
                            id: "\(sectionPrefix)#\(builtGroups.count)",
                            name: group.name,
                            tweaks: group.tweaks.map { makeMetadata($0, sectionPrefix: sectionPrefix) }
                        ))
                    }
                }
                flushUngrouped()

                let sectionMetadata = TweakSectionMetadata(
                    id: sectionPrefix,
                    name: section.name,
                    groups: builtGroups,
                    hasMasterToggle: section.hasMasterToggle,
                    tag: section.tag,
                    color: section.color
                )
                for tweak in sectionMetadata.tweaks {
                    allSections[tweak.id] = sectionMetadata
                }
                builtSections.append(sectionMetadata)
            }

            builtCategories.append(TweakCategoryMetadata(
                id: category.name,
                name: category.name,
                icon: category.icon,
                sections: builtSections
            ))
        }

        self.categories = builtCategories
        self.tweaksByKey = allTweaks
        self.sectionsByKey = allSections
        self.defaultsByKey = allDefaults
    }

    // MARK: - Subscript Access

    /// Read a tweak value by its full key path.
    ///
    /// Returns the stored override or the DSL default. Traps if the key is not found.
    public subscript<T: Equatable>(key: String) -> T {
        get {
            guard let defaultValue = defaultsByKey[key] else {
                fatalError("TweakIt: Unknown key '\(key)'. Check your TweakStore definition.")
            }
            guard let typed = defaultValue as? T else {
                fatalError("TweakIt: Type mismatch for key '\(key)'. Expected \(T.self), got \(type(of: defaultValue)).")
            }
            return storage.value(forKey: key, default: typed)
        }
        set {
            guard let defaultValue = defaultsByKey[key] as? T else {
                fatalError("TweakIt: Unknown or type-mismatched key '\(key)'.")
            }
            storage.setValue(newValue, forKey: key, default: defaultValue)
        }
    }

    // MARK: - TweakRef Factory

    /// Creates a typed reference handle for ergonomic dot-syntax access.
    ///
    /// ```swift
    /// static let duration = store.ref("Visual.Modal Cards.duration", as: CGFloat.self)
    /// // Usage: duration.value, duration.value = 0.5
    /// ```
    public func ref<T: Equatable>(_ key: String, as _: T.Type) -> TweakRef<T> {
        guard let defaultValue = defaultsByKey[key] else {
            fatalError("TweakIt: Unknown key '\(key)'. Check your TweakStore definition.")
        }
        guard let typed = defaultValue as? T else {
            fatalError("TweakIt: Type mismatch for key '\(key)'. Expected \(T.self), got \(Swift.type(of: defaultValue)).")
        }
        return TweakRef(key: key, defaultValue: typed, storage: storage)
    }

    /// Creates a typed reference handle, inferring the type from context.
    ///
    /// ```swift
    /// static let duration: TweakRef<CGFloat> = store.ref("Visual.Modal Cards.duration")
    /// ```
    public func ref<T: Equatable>(_ key: String) -> TweakRef<T> {
        ref(key, as: T.self)
    }

    // MARK: - Lookups

    /// Looks up a tweak's metadata by its full key path.
    ///
    /// Returns `nil` for a key with no definition in this store — which is the expected
    /// outcome for a *ghost key*: one persisted by pins or recents whose tweak has since
    /// been renamed or deleted. Callers holding stored keys should filter through this
    /// and skip the misses rather than assume a definition exists.
    public func tweak(forKey key: String) -> TweakMetadata? {
        tweaksByKey[key]
    }

    /// Looks up the section that declares the given tweak key.
    ///
    /// Backed by a dictionary built at init, not by parsing the key — section names
    /// routinely contain spaces and may contain dots. Returns `nil` for a ghost key.
    public func section(containing key: String) -> TweakSectionMetadata? {
        sectionsByKey[key]
    }

    // MARK: - Section Queries

    /// Whether the master toggle for a section is enabled.
    public func isSectionEnabled(_ sectionID: String) -> Bool {
        storage.value(forKey: sectionID + ".isEnabled", default: false)
    }
}
