//
//  TweakDefinition.swift
//  TweakIt
//
//  Result builder DSL node types for defining tweaks in a single place.
//

import Foundation
import SwiftUI

// MARK: - DSL Node Types

/// A category of tweak sections, displayed as a collapsible group in the UI.
public struct TweakCategory {
    public let name: String
    public let icon: String
    public let sections: [TweakSection]

    public init(_ name: String, icon: String, @TweakSectionBuilder sections: () -> [TweakSection]) {
        self.name = name
        self.icon = icon
        self.sections = sections()
    }
}

/// One entry in a section's body: either a bare tweak or a named ``TweakGroup``.
///
/// A section's body is a mixed list so that grouped and ungrouped tweaks can be
/// interleaved in declaration order:
///
/// ```swift
/// TweakSection("Card") {
///     TweakDefinition("enabled", default: true)   // .tweak
///     TweakGroup("Shape") {                       // .group
///         TweakDefinition("cornerRadius", default: 12.0, range: 0...40)
///     }
/// }
/// ```
public enum TweakSectionItem {
    /// A tweak declared directly in the section body, outside any group.
    case tweak(TweakDefinition)
    /// A named group of tweaks.
    case group(TweakGroup)

    /// Every definition this item contributes, in declaration order.
    public var definitions: [TweakDefinition] {
        switch self {
        case .tweak(let definition): return [definition]
        case .group(let group): return group.tweaks
        }
    }
}

/// A named sub-heading inside a ``TweakSection``.
///
/// Groups exist purely to organize a long section visually — they let you replace
/// `// — Shape —` source comments with something the panel can actually render:
///
/// ```swift
/// TweakSection("Modal Cards") {
///     TweakDefinition("enabled", default: true)
///     TweakGroup("Shape") {
///         TweakDefinition("cornerRadius", default: 12.0, range: 0...40)
///         TweakDefinition("shadowRadius", default: 8.0, range: 0...40)
///     }
/// }
/// ```
///
/// - Important: A group name is **not** part of a tweak's storage key. The key stays
///   `"Category.Section.tweak"` whether the tweak is declared bare or inside a group,
///   so wrapping existing tweaks in a group never resets values already dialled in on device.
///
/// - Note: Groups don't nest. A `TweakGroup` declared inside another group is flattened
///   into its parent rather than producing a second level of heading.
public struct TweakGroup {
    /// Display name shown as a sub-heading in the panel.
    public let name: String
    /// The tweaks in this group, in declaration order.
    public let tweaks: [TweakDefinition]

    /// Creates a named group of tweaks.
    ///
    /// - Parameters:
    ///   - name: The sub-heading shown in the panel. Not part of any storage key.
    ///   - tweaks: A result builder closure returning the group's tweaks.
    public init(_ name: String, @TweakDefinitionBuilder tweaks: () -> [TweakSectionItem]) {
        self.name = name
        self.tweaks = tweaks().flatMap(\.definitions)
    }
}

/// A section of tweaks within a category.
public struct TweakSection {
    public let name: String
    public let hasMasterToggle: Bool
    public let tag: AnyHashable?
    public let color: Color?

    /// The section body in declaration order — bare tweaks and named groups, interleaved.
    public let items: [TweakSectionItem]

    /// Every tweak in this section, flattened across groups, in declaration order.
    public var tweaks: [TweakDefinition] {
        items.flatMap(\.definitions)
    }

    public init(
        _ name: String,
        hasMasterToggle: Bool = false,
        tag: AnyHashable? = nil,
        color: Color? = nil,
        @TweakDefinitionBuilder tweaks: () -> [TweakSectionItem]
    ) {
        self.name = name
        self.hasMasterToggle = hasMasterToggle
        self.tag = tag
        self.color = color
        self.items = tweaks()
    }
}

/// A single tweak definition. The type of control is inferred from the default value and parameters.
public struct TweakDefinition {
    public let name: String
    public let defaultValue: Any
    public let range: ClosedRange<Double>?
    public let options: [String]?
    public let action: (() -> Void)?

    /// Optional one-line explanation shown under the tweak's name in the panel.
    ///
    /// Use it when the name alone is cryptic — `"ignoreEngagedFloor"` means nothing six months later.
    /// Keep it short; the panel renders it as small monospaced text, not a paragraph.
    public let description: String?

    // MARK: - Bool tweak (toggle)

    public init(_ name: String, default defaultValue: Bool, description: String? = nil) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = nil
        self.options = nil
        self.action = nil
        self.description = description
    }

    // MARK: - Double tweak (slider)

    public init(_ name: String, default defaultValue: Double, range: ClosedRange<Double>, description: String? = nil) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = range
        self.options = nil
        self.action = nil
        self.description = description
    }

    // MARK: - CGFloat tweak (slider)

    public init(_ name: String, default defaultValue: CGFloat, range: ClosedRange<Double>, description: String? = nil) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = range
        self.options = nil
        self.action = nil
        self.description = description
    }

    // MARK: - Int tweak (stepper or slider)

    /// Int tweak with no range — rendered as a stepper.
    public init(_ name: String, default defaultValue: Int, description: String? = nil) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = nil
        self.options = nil
        self.action = nil
        self.description = description
    }

    /// Int tweak with range — rendered as a slider.
    public init(_ name: String, default defaultValue: Int, range: ClosedRange<Double>, description: String? = nil) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = range
        self.options = nil
        self.action = nil
        self.description = description
    }

    // MARK: - String tweak (text field)

    public init(_ name: String, default defaultValue: String, description: String? = nil) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = nil
        self.options = nil
        self.action = nil
        self.description = description
    }

    // MARK: - Picker tweak (string options)

    public init(_ name: String, default defaultValue: String, options: [String], description: String? = nil) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = nil
        self.options = options
        self.action = nil
        self.description = description
    }

    // MARK: - Action tweak (button)

    public init(_ name: String, action: @escaping () -> Void, description: String? = nil) {
        self.name = name
        self.defaultValue = false
        self.range = nil
        self.options = nil
        self.action = action
        self.description = description
    }
}

// MARK: - Result Builders

/// Result builder for assembling `TweakCategory` arrays.
@resultBuilder
public struct TweakCategoryBuilder {
    public static func buildBlock(_ components: TweakCategory...) -> [TweakCategory] {
        components
    }

    public static func buildOptional(_ component: [TweakCategory]?) -> [TweakCategory] {
        component ?? []
    }

    public static func buildEither(first component: [TweakCategory]) -> [TweakCategory] {
        component
    }

    public static func buildEither(second component: [TweakCategory]) -> [TweakCategory] {
        component
    }

    public static func buildArray(_ components: [[TweakCategory]]) -> [TweakCategory] {
        components.flatMap { $0 }
    }
}

/// Result builder for assembling `TweakSection` arrays.
@resultBuilder
public struct TweakSectionBuilder {
    public static func buildBlock(_ components: TweakSection...) -> [TweakSection] {
        components
    }

    public static func buildOptional(_ component: [TweakSection]?) -> [TweakSection] {
        component ?? []
    }

    public static func buildEither(first component: [TweakSection]) -> [TweakSection] {
        component
    }

    public static func buildEither(second component: [TweakSection]) -> [TweakSection] {
        component
    }

    public static func buildArray(_ components: [[TweakSection]]) -> [TweakSection] {
        components.flatMap { $0 }
    }
}

/// Result builder for assembling the body of a ``TweakSection`` or ``TweakGroup``.
///
/// Accepts both ``TweakDefinition`` and ``TweakGroup`` statements, producing a flat
/// list of ``TweakSectionItem`` in declaration order. Supports `if`/`else`, `if let`,
/// and `for…in`.
@resultBuilder
public struct TweakDefinitionBuilder {
    public static func buildExpression(_ definition: TweakDefinition) -> [TweakSectionItem] {
        [.tweak(definition)]
    }

    public static func buildExpression(_ group: TweakGroup) -> [TweakSectionItem] {
        [.group(group)]
    }

    public static func buildBlock(_ parts: [TweakSectionItem]...) -> [TweakSectionItem] {
        parts.flatMap { $0 }
    }

    public static func buildOptional(_ component: [TweakSectionItem]?) -> [TweakSectionItem] {
        component ?? []
    }

    public static func buildEither(first component: [TweakSectionItem]) -> [TweakSectionItem] {
        component
    }

    public static func buildEither(second component: [TweakSectionItem]) -> [TweakSectionItem] {
        component
    }

    public static func buildArray(_ components: [[TweakSectionItem]]) -> [TweakSectionItem] {
        components.flatMap { $0 }
    }
}
