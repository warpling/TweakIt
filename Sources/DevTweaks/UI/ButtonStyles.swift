//
//  ButtonStyles.swift
//  DevTweaks
//
//  Shared button styles for the tweak panel UI.
//

import SwiftUI

/// A PrimitiveButtonStyle that provides reliable press feedback inside List rows.
///
/// SwiftUI List absorbs touch-down events before regular ButtonStyle.isPressed fires.
/// This works around it by handling tap/press gestures directly and calling trigger() manually.
@available(iOS 16.0, *)
struct ListHighlightButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ListHighlightButton(configuration: configuration)
    }

    struct ListHighlightButton: View {
        let configuration: Configuration
        @State private var isPressed = false

        var body: some View {
            configuration.label
                .opacity(isPressed ? 0.5 : 1.0)
                .scaleEffect(isPressed ? 0.97 : 1.0)
                .animation(isPressed ? nil : .easeOut(duration: 0.2), value: isPressed)
                .onLongPressGesture(minimumDuration: 9999, pressing: { pressing in
                    isPressed = pressing
                }, perform: { })
                .simultaneousGesture(TapGesture().onEnded {
                    configuration.trigger()
                })
        }
    }
}

/// Button style with press feedback for the floating button (pre-iOS 26).
@available(iOS 16.0, *)
struct FloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
