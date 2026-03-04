//
//  TweakStore.swift
//  DevTweaks
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
        var builtCategories = [TweakCategoryMetadata]()

        for category in defs {
            var builtSections = [TweakSectionMetadata]()

            for section in category.sections {
                let sectionPrefix = "\(category.name).\(section.name)"
                var builtTweaks = [TweakMetadata]()

                for tweak in section.tweaks {
                    let key = "\(sectionPrefix).\(tweak.name)"
                    let metadata: TweakMetadata
                    if let action = tweak.action {
                        metadata = TweakMetadata(id: key, name: tweak.name, action: action)
                    } else {
                        metadata = TweakMetadata(
                            id: key,
                            name: tweak.name,
                            defaultValue: tweak.defaultValue,
                            range: tweak.range,
                            options: tweak.options
                        )
                    }
                    builtTweaks.append(metadata)
                    allTweaks[key] = metadata
                    allDefaults[key] = tweak.defaultValue
                }

                builtSections.append(TweakSectionMetadata(
                    id: sectionPrefix,
                    name: section.name,
                    tweaks: builtTweaks,
                    hasMasterToggle: section.hasMasterToggle,
                    tag: section.tag,
                    color: section.color
                ))
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
        self.defaultsByKey = allDefaults
    }

    // MARK: - Subscript Access

    /// Read a tweak value by its full key path.
    ///
    /// Returns the stored override or the DSL default. Traps if the key is not found.
    public subscript<T: Equatable>(key: String) -> T {
        get {
            guard let defaultValue = defaultsByKey[key] else {
                fatalError("DevTweaks: Unknown key '\(key)'. Check your TweakStore definition.")
            }
            guard let typed = defaultValue as? T else {
                fatalError("DevTweaks: Type mismatch for key '\(key)'. Expected \(T.self), got \(type(of: defaultValue)).")
            }
            return storage.value(forKey: key, default: typed)
        }
        set {
            guard let defaultValue = defaultsByKey[key] as? T else {
                fatalError("DevTweaks: Unknown or type-mismatched key '\(key)'.")
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
            fatalError("DevTweaks: Unknown key '\(key)'. Check your TweakStore definition.")
        }
        guard let typed = defaultValue as? T else {
            fatalError("DevTweaks: Type mismatch for key '\(key)'. Expected \(T.self), got \(Swift.type(of: defaultValue)).")
        }
        return TweakRef(key: key, defaultValue: typed, storage: storage)
    }

    // MARK: - Section Queries

    /// Whether the master toggle for a section is enabled.
    public func isSectionEnabled(_ sectionID: String) -> Bool {
        storage.value(forKey: sectionID + ".isEnabled", default: false)
    }
}
