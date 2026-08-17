//
//  TweakPanel.swift
//  TweakIt
//
//  Public API for installing and presenting the tweak panel.
//

import UIKit
import SwiftUI

/// Public entry point for installing the TweakIt UI into your app.
///
/// Call `install(store:)` once at launch — it's safe to call from
/// `didFinishLaunchingWithOptions` before a window scene is connected.
///
/// ```swift
/// TweakIt.isEnabled = true  // opt-in for non-debug builds
/// TweakPanel.install(store: AppTweaks.store)
/// ```
public enum TweakPanel {

    @available(iOS 16.0, *)
    private static var windowManager: TweakPanelWindowManager?

    /// Installs the tweak panel UI.
    ///
    /// Safe to call from `didFinishLaunchingWithOptions` — if no window scene
    /// is connected yet, setup defers automatically until one activates.
    /// No-ops when `TweakIt.isEnabled` is `false`.
    ///
    /// - Parameters:
    ///   - store: The `TweakStore` containing all tweak definitions.
    ///   - tabs: Optional custom tabs to show alongside the tweaks browser.
    ///   - buttonIcon: SF Symbol name for the floating button. Defaults to `"slider.vertical.3"`.
    ///   - buttonInitiallyVisible: Whether the floating button starts visible. Defaults to `true`.
    ///   - buttonBottomOffset: Extra bottom padding for the floating button (e.g., to clear a tab bar). Defaults to `0`.
    ///   - shakeToToggleButton: Whether shaking the device toggles button visibility. Defaults to `true`.
    ///   - onDismiss: Optional closure called when the panel is dismissed.
    @available(iOS 16.0, *)
    public static func install(
        store: TweakStore,
        tabs: [TweakTab] = [],
        buttonIcon: String = "slider.vertical.3",
        buttonInitiallyVisible: Bool = true,
        buttonBottomOffset: CGFloat = 0,
        shakeToToggleButton: Bool = true,
        onDismiss: (() -> Void)? = nil
    ) {
        install(
            store: store,
            tabs: tabs,
            buttonAlignment: .bottomLeading,
            buttonInset: 16,
            buttonIgnoresSafeArea: false,
            buttonBottomOffset: buttonBottomOffset,
            buttonInitiallyVisible: buttonInitiallyVisible,
            shakeToToggleButton: shakeToToggleButton,
            onDismiss: onDismiss,
            button: { present in
                TweakPanelFloatingButton(icon: buttonIcon, action: present)
            }
        )
    }

    /// Installs the tweak panel with a host-supplied toggle button.
    ///
    /// The package keeps ownership of the pass-through window, the button's
    /// visibility state, shake-to-toggle and panel presentation; the host
    /// supplies only appearance and placement, so the button can match the
    /// app's own design system.
    ///
    /// Pass `{ _ in EmptyView() }` to suppress the button entirely and drive
    /// ``present(selectingTab:)`` yourself.
    ///
    /// - Parameters:
    ///   - store: The `TweakStore` containing all tweak definitions.
    ///   - tabs: Optional custom tabs to show alongside the tweaks browser.
    ///   - buttonAlignment: Corner the button is pinned to. Default `.bottomLeading`.
    ///   - buttonInset: Distance from the container's edges. Default `16`.
    ///   - buttonIgnoresSafeArea: When `true`, `buttonInset` is measured from
    ///     the physical screen edge instead of the safe area — needed to line
    ///     the button up with other corner-anchored chrome. Default `false`.
    ///   - buttonInitiallyVisible: Whether the floating button starts visible. Defaults to `true`.
    ///   - shakeToToggleButton: Whether shaking the device toggles button visibility. Defaults to `true`.
    ///   - onDismiss: Optional closure called when the panel is dismissed.
    ///   - button: Builds the button. The closure it receives presents the panel.
    ///     The returned view's frame becomes the tappable region — the
    ///     pass-through window claims exactly that frame for touches, so keep
    ///     it tight to the visible control (size it with `.frame(...)`/
    ///     `.contentShape(...)` on the control itself) rather than adding
    ///     outer padding, or the padding becomes a dead zone that swallows
    ///     touches before they reach your app. The closure is invoked exactly
    ///     once, at setup — the manager builds and holds the erased view then,
    ///     so it won't re-run on state changes; back any dynamic appearance
    ///     with `@ObservedObject`/`@State` inside the returned view instead.
    @available(iOS 16.0, *)
    public static func install<Button: View>(
        store: TweakStore,
        tabs: [TweakTab] = [],
        buttonAlignment: Alignment = .bottomLeading,
        buttonInset: CGFloat = 16,
        buttonIgnoresSafeArea: Bool = false,
        buttonInitiallyVisible: Bool = true,
        shakeToToggleButton: Bool = true,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder button: @escaping (@escaping () -> Void) -> Button
    ) {
        install(
            store: store,
            tabs: tabs,
            buttonAlignment: buttonAlignment,
            buttonInset: buttonInset,
            buttonIgnoresSafeArea: buttonIgnoresSafeArea,
            buttonBottomOffset: 0,
            buttonInitiallyVisible: buttonInitiallyVisible,
            shakeToToggleButton: shakeToToggleButton,
            onDismiss: onDismiss,
            button: button
        )
    }

    /// Shared implementation behind both public `install` overloads.
    ///
    /// `buttonBottomOffset` is internal-only — it exists solely so the legacy
    /// `install(store:tabs:buttonIcon:buttonInitiallyVisible:buttonBottomOffset:shakeToToggleButton:onDismiss:)`
    /// overload can keep its old layout. It's threaded to
    /// `TweakPanelButtonContainer`'s `bottomOffset`, applied on the container
    /// after `buttonInset` rather than inside `button`'s content, so it
    /// doesn't inflate the frame `reportButtonFrame()` reports for hit
    /// testing.
    @available(iOS 16.0, *)
    private static func install<Button: View>(
        store: TweakStore,
        tabs: [TweakTab],
        buttonAlignment: Alignment,
        buttonInset: CGFloat,
        buttonIgnoresSafeArea: Bool,
        buttonBottomOffset: CGFloat,
        buttonInitiallyVisible: Bool,
        shakeToToggleButton: Bool,
        onDismiss: (() -> Void)?,
        @ViewBuilder button: @escaping (@escaping () -> Void) -> Button
    ) {
        guard TweakIt.isEnabled else { return }

        let manager = TweakPanelWindowManager(
            store: store,
            tabs: tabs,
            buttonAlignment: buttonAlignment,
            buttonInset: buttonInset,
            buttonIgnoresSafeArea: buttonIgnoresSafeArea,
            buttonContent: { present in AnyView(button(present)) },
            buttonInitiallyVisible: buttonInitiallyVisible,
            buttonBottomOffset: buttonBottomOffset,
            shakeToToggleButton: shakeToToggleButton,
            onDismiss: onDismiss
        )
        manager.setup()
        windowManager = manager
    }

    /// The button state, for toggling visibility from UIKit code.
    @available(iOS 16.0, *)
    public static var buttonState: TweakPanelButtonState? {
        return windowManager?.buttonState
    }

    /// Programmatically presents the tweak panel.
    ///
    /// - Parameter selectingTab: Optional tab name to select on presentation.
    ///   When `nil`, the panel restores the last-used tab.
    @available(iOS 16.0, *)
    public static func present(selectingTab: String? = nil) {
        guard TweakIt.isEnabled else { return }
        windowManager?.presentPanel(selectingTab: selectingTab)
    }

    /// Creates a `UIWindow` subclass with a two-finger double-tap gesture that opens the panel.
    ///
    /// Use this as your app's main window if you want the gesture shortcut:
    /// ```swift
    /// window = TweakPanel.makeWindow(windowScene: windowScene)
    /// ```
    @available(iOS 16.0, *)
    public static func makeWindow(frame: CGRect) -> UIWindow {
        guard TweakIt.isEnabled else { return UIWindow(frame: frame) }
        return TweakGestureWindow(frame: frame)
    }

    /// Creates a `UIWindow` subclass with a two-finger double-tap gesture that opens the panel.
    @available(iOS 16.0, *)
    public static func makeWindow(windowScene: UIWindowScene) -> UIWindow {
        guard TweakIt.isEnabled else { return UIWindow(windowScene: windowScene) }
        return TweakGestureWindow(windowScene: windowScene)
    }
}

// MARK: - Gesture Window

/// A UIWindow that captures two-finger double-tap to present the tweak panel.
@available(iOS 16.0, *)
final class TweakGestureWindow: UIWindow {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGesture()
    }

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        setupGesture()
    }

    private func setupGesture() {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        gesture.numberOfTapsRequired = 2
        gesture.numberOfTouchesRequired = 2
        gesture.cancelsTouchesInView = false
        gesture.delaysTouchesBegan = false
        gesture.delaysTouchesEnded = false
        addGestureRecognizer(gesture)
    }

    @objc private func handleGesture(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .recognized else { return }
        TweakPanel.present()
    }
}
