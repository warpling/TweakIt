//
//  TweakDefinition.swift
//  DevTweaks
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

/// A section of tweaks within a category.
public struct TweakSection {
    public let name: String
    public let hasMasterToggle: Bool
    public let tag: AnyHashable?
    public let color: Color?
    public let tweaks: [TweakDefinition]

    public init(
        _ name: String,
        hasMasterToggle: Bool = false,
        tag: AnyHashable? = nil,
        color: Color? = nil,
        @TweakDefinitionBuilder tweaks: () -> [TweakDefinition]
    ) {
        self.name = name
        self.hasMasterToggle = hasMasterToggle
        self.tag = tag
        self.color = color
        self.tweaks = tweaks()
    }
}

/// A single tweak definition. The type of control is inferred from the default value and parameters.
public struct TweakDefinition {
    public let name: String
    public let defaultValue: Any
    public let range: ClosedRange<Double>?
    public let options: [String]?
    public let action: (() -> Void)?

    // MARK: - Bool tweak (toggle)

    public init(_ name: String, default defaultValue: Bool) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = nil
        self.options = nil
        self.action = nil
    }

    // MARK: - Double tweak (slider)

    public init(_ name: String, default defaultValue: Double, range: ClosedRange<Double>) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = range
        self.options = nil
        self.action = nil
    }

    // MARK: - CGFloat tweak (slider)

    public init(_ name: String, default defaultValue: CGFloat, range: ClosedRange<Double>) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = range
        self.options = nil
        self.action = nil
    }

    // MARK: - Int tweak (stepper or slider)

    /// Int tweak with no range — rendered as a stepper.
    public init(_ name: String, default defaultValue: Int) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = nil
        self.options = nil
        self.action = nil
    }

    /// Int tweak with range — rendered as a slider.
    public init(_ name: String, default defaultValue: Int, range: ClosedRange<Double>) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = range
        self.options = nil
        self.action = nil
    }

    // MARK: - String tweak (text field)

    public init(_ name: String, default defaultValue: String) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = nil
        self.options = nil
        self.action = nil
    }

    // MARK: - Picker tweak (string options)

    public init(_ name: String, default defaultValue: String, options: [String]) {
        self.name = name
        self.defaultValue = defaultValue
        self.range = nil
        self.options = options
        self.action = nil
    }

    // MARK: - Action tweak (button)

    public init(_ name: String, action: @escaping () -> Void) {
        self.name = name
        self.defaultValue = false
        self.range = nil
        self.options = nil
        self.action = action
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

/// Result builder for assembling `TweakDefinition` arrays.
@resultBuilder
public struct TweakDefinitionBuilder {
    public static func buildBlock(_ components: TweakDefinition...) -> [TweakDefinition] {
        components
    }

    public static func buildOptional(_ component: [TweakDefinition]?) -> [TweakDefinition] {
        component ?? []
    }

    public static func buildEither(first component: [TweakDefinition]) -> [TweakDefinition] {
        component
    }

    public static func buildEither(second component: [TweakDefinition]) -> [TweakDefinition] {
        component
    }

    public static func buildArray(_ components: [[TweakDefinition]]) -> [TweakDefinition] {
        components.flatMap { $0 }
    }
}
