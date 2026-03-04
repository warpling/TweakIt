//
//  TweakTab.swift
//  DevTweaks
//
//  Custom tab type for adding app-specific panels alongside the tweaks browser.
//

import SwiftUI

/// A custom tab that can be added to the tweak panel alongside the built-in tweaks browser.
///
/// ```swift
/// TweakTab("Actions", icon: "bolt") { ActionsView() }
/// ```
public struct TweakTab {
    /// Display name shown in the segmented picker.
    public let name: String
    /// SF Symbol name for the tab icon.
    public let icon: String
    /// Closure that produces the tab's SwiftUI content.
    let content: () -> AnyView

    /// Creates a custom tab.
    ///
    /// - Parameters:
    ///   - name: Display name.
    ///   - icon: SF Symbol name.
    ///   - content: A closure returning the SwiftUI view for this tab.
    public init<Content: View>(_ name: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.name = name
        self.icon = icon
        self.content = { AnyView(content()) }
    }
}
