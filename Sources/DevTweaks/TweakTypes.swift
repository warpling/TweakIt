//
//  TweakTypes.swift
//  DevTweaks
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

    /// Creates a value tweak.
    public init(id: String, name: String, defaultValue: Any, range: ClosedRange<Double>? = nil, options: [String]? = nil) {
        self.id = id
        self.name = name
        self.defaultValue = defaultValue
        self.range = range
        self.options = options
        self.action = nil
    }

    /// Creates an action-button tweak that fires a closure on tap.
    public init(id: String, name: String, action: @escaping () -> Void) {
        self.id = id
        self.name = name
        self.defaultValue = false
        self.range = nil
        self.options = nil
        self.action = action
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

// MARK: - Section Metadata

/// Metadata for a section of tweaks.
public struct TweakSectionMetadata: Identifiable {
    /// Section key prefix (e.g., "Visual.Modal Cards").
    public let id: String
    /// Display name.
    public let name: String
    /// The tweaks in this section.
    public let tweaks: [TweakMetadata]
    /// Whether this section has a master enable/disable toggle.
    public let hasMasterToggle: Bool
    /// Optional tag for app-specific decoration (e.g., a challenge type).
    public let tag: AnyHashable?
    /// Optional color for app-specific decoration.
    public let color: Color?

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
