//
//  TweakTypes.swift
//  TweakIt
//
//  Metadata types describing tweaks, sections, and categories for UI rendering.
//

import Foundation
import SwiftUI

// MARK: - Tweak Metadata

/// Metadata describing a single tweak for UI rendering.
public struct TweakMetadata: Identifiable {
    /// Full key path (e.g., "Visual.Modal Cards.duration").
    public let id: String
    /// Display name shown in the UI.
    public let name: String
    /// The default value for this tweak.
    public let defaultValue: Any
    /// Numeric range constraint (for slider tweaks).
    public let range: ClosedRange<Double>?
    /// Available choices (for picker tweaks).
    public let options: [String]?
    /// Closure fired on tap (for action-button tweaks).
    public let action: (() -> Void)?
    /// Optional one-line explanation shown under the tweak's name, from
    /// ``TweakDefinition/description``. `nil` when the declaration didn't supply one.
    public let description: String?

    /// Creates a value tweak.
    public init(
        id: String,
        name: String,
        defaultValue: Any,
        range: ClosedRange<Double>? = nil,
        options: [String]? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.defaultValue = defaultValue
        self.range = range
        self.options = options
        self.action = nil
        self.description = description
    }

    /// Creates an action-button tweak that fires a closure on tap.
    public init(id: String, name: String, action: @escaping () -> Void, description: String? = nil) {
        self.id = id
        self.name = name
        self.defaultValue = false
        self.range = nil
        self.options = nil
        self.action = action
        self.description = description
    }

    /// Type of control to display in the UI.
    public enum ControlType {
        case toggle
        case slider
        case stepper
        case picker
        case text
        case action
    }

    /// Inferred control type based on the default value and metadata.
    public var controlType: ControlType {
        if action != nil { return .action }
        if options != nil { return .picker }
        if defaultValue is Bool { return .toggle }
        if defaultValue is Int { return range != nil ? .slider : .stepper }
        if defaultValue is Double || defaultValue is CGFloat { return .slider }
        if defaultValue is String { return .text }
        return .text
    }
}

// MARK: - Group Metadata

/// Metadata for a named group of tweaks inside a section.
///
/// A section's tweaks are always delivered as groups. Tweaks declared bare — outside any
/// ``TweakGroup`` — arrive as a group with a `nil` ``name``: the *implicit ungrouped run*.
/// A section may contain several ungrouped runs if bare tweaks are interleaved with groups;
/// each contiguous run is its own `TweakGroupMetadata`, so declaration order is preserved.
///
/// Render a `nil` name as no heading at all, not as an empty one.
public struct TweakGroupMetadata: Identifiable {
    /// Identity within the section. Opaque — derived from the section key and the group's
    /// position, not from the group name. Don't parse it or use it as a storage key.
    public let id: String
    /// Display name for the sub-heading, or `nil` for the implicit ungrouped run.
    public let name: String?
    /// The tweaks in this group, in declaration order.
    public let tweaks: [TweakMetadata]

    public init(id: String, name: String?, tweaks: [TweakMetadata]) {
        self.id = id
        self.name = name
        self.tweaks = tweaks
    }
}

// MARK: - Section Metadata

/// Metadata for a section of tweaks.
public struct TweakSectionMetadata: Identifiable {
    /// Section key prefix (e.g., "Visual.Modal Cards").
    public let id: String
    /// Display name.
    public let name: String
    /// The tweaks in this section, flattened across groups, in declaration order.
    public let tweaks: [TweakMetadata]
    /// The tweaks in this section as declared — named groups and ungrouped runs, in order.
    public let groups: [TweakGroupMetadata]
    /// Whether this section has a master enable/disable toggle.
    public let hasMasterToggle: Bool
    /// Optional tag for app-specific decoration (e.g., a challenge type).
    public let tag: AnyHashable?
    /// Optional color for app-specific decoration.
    public let color: Color?

    /// Creates section metadata from a flat list of tweaks.
    ///
    /// The tweaks become a single implicit ungrouped run, so ``groups`` always has
    /// exactly one entry with a `nil` name.
    public init(
        id: String,
        name: String,
        tweaks: [TweakMetadata],
        hasMasterToggle: Bool = false,
        tag: AnyHashable? = nil,
        color: Color? = nil
    ) {
        self.id = id
        self.name = name
        self.tweaks = tweaks
        self.groups = [TweakGroupMetadata(id: "\(id)#0", name: nil, tweaks: tweaks)]
        self.hasMasterToggle = hasMasterToggle
        self.tag = tag
        self.color = color
    }

    /// Creates section metadata from grouped tweaks.
    ///
    /// ``tweaks`` is flattened from `groups` in order, so callers that only care about the
    /// flat list keep working.
    public init(
        id: String,
        name: String,
        groups: [TweakGroupMetadata],
        hasMasterToggle: Bool = false,
        tag: AnyHashable? = nil,
        color: Color? = nil
    ) {
        self.id = id
        self.name = name
        self.groups = groups
        self.tweaks = groups.flatMap(\.tweaks)
        self.hasMasterToggle = hasMasterToggle
        self.tag = tag
        self.color = color
    }
}

// MARK: - Category Metadata

/// Metadata for a category of tweak sections.
public struct TweakCategoryMetadata: Identifiable {
    /// Category name (e.g., "Visual").
    public let id: String
    /// Display name.
    public let name: String
    /// SF Symbol name for the category header.
    public let icon: String
    /// The sections in this category.
    public let sections: [TweakSectionMetadata]

    public init(id: String, name: String, icon: String, sections: [TweakSectionMetadata]) {
        self.id = id
        self.name = name
        self.icon = icon
        self.sections = sections
    }
}
