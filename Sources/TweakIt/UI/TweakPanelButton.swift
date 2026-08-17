//
//  TweakPanelButton.swift
//  TweakIt
//
//  Floating button that opens the tweak panel. Supports liquid glass on iOS 26+.
//

import SwiftUI

/// Observable state for the floating button visibility, controllable from UIKit.
@available(iOS 16.0, *)
public final class TweakPanelButtonState: ObservableObject {
    @Published public var isVisible: Bool

    /// Button frame in screen coordinates, updated by SwiftUI geometry.
    /// Read by PassThroughWindow for hit testing — not @Published to avoid re-renders.
    var buttonFrame: CGRect = .zero

    public init(initiallyVisible: Bool = true) {
        self.isVisible = initiallyVisible
    }

    public func toggle() {
        withAnimation(.bouncy) {
            isVisible.toggle()
        }
    }
}

// MARK: - Button Frame Preference Key

@available(iOS 16.0, *)
private struct ButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// Container view that hosts the floating toggle button with glass
/// transitions on iOS 26+. The content is supplied by the host app so it can
/// match its own design system; `TweakPanel.install` passes the built-in
/// button when the host doesn't provide one.
@available(iOS 16.0, *)
struct TweakPanelButtonContainer<Content: View>: View {
    @ObservedObject var state: TweakPanelButtonState
    let alignment: Alignment
    let inset: CGFloat
    let ignoresSafeArea: Bool
    /// Extra bottom padding applied on the container, after `inset` — kept
    /// internal for the legacy `install` overload's `buttonBottomOffset`.
    /// Applied here (not inside `content`) so it doesn't shrink the reported
    /// hit-testing frame from `reportButtonFrame()`.
    var bottomOffset: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer {
                    if state.isVisible {
                        content()
                            .glassEffectID("tweakItButton", in: glassNamespace)
                            .reportButtonFrame()
                    }
                }
            } else {
                Group {
                    if state.isVisible {
                        content()
                            .transition(.scale.combined(with: .opacity))
                            .reportButtonFrame()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .padding(inset)
        .padding(.bottom, bottomOffset)
        .modifier(IgnoreSafeAreaIf(active: ignoresSafeArea))
        .onPreferenceChange(ButtonFrameKey.self) { state.buttonFrame = $0 }
    }

    @Namespace private var glassNamespace
}

/// `.ignoresSafeArea()` isn't conditionally applicable inline without
/// changing the view's type, so it's wrapped in a modifier.
@available(iOS 16.0, *)
private struct IgnoreSafeAreaIf: ViewModifier {
    let active: Bool
    @ViewBuilder
    func body(content: Content) -> some View {
        if active { content.ignoresSafeArea() } else { content }
    }
}

@available(iOS 16.0, *)
private extension View {
    func reportButtonFrame() -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: ButtonFrameKey.self, value: geo.frame(in: .global))
            }
        )
    }
}

/// The floating button itself.
@available(iOS 16.0, *)
struct TweakPanelFloatingButton: View {
    let icon: String
    let action: () -> Void

    private let buttonSize: CGFloat = 62
    private let iconSize: CGFloat = 20

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: buttonSize, height: buttonSize)
            }
            .buttonStyle(.plain)
            .clipShape(Circle())
            .glassEffect(.regular.interactive())
            .environment(\.colorScheme, .dark)
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            .accessibilityLabel("Dev Tools")
            .accessibilityHint("Opens developer tools panel")
        } else {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(FloatingButtonStyle())
            .accessibilityLabel("Dev Tools")
            .accessibilityHint("Opens developer tools panel")
        }
    }
}
