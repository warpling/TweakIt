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
/// #if DEBUG
/// TweakPanel.install(store: AppTweaks.store)
/// #endif
/// ```
public enum TweakPanel {

    #if DEBUG
    @available(iOS 16.0, *)
    private static var windowManager: TweakPanelWindowManager?
    #endif

    /// Installs the tweak panel UI.
    ///
    /// Safe to call from `didFinishLaunchingWithOptions` — if no window scene
    /// is connected yet, setup defers automatically until one activates.
    ///
    /// - Parameters:
    ///   - store: The `TweakStore` containing all tweak definitions.
    ///   - tabs: Optional custom tabs to show alongside the tweaks browser.
    ///   - buttonIcon: SF Symbol name for the floating button. Defaults to `"slider.vertical.3"`.
    ///   - buttonInitiallyVisible: Whether the floating button starts visible. Defaults to `true`.
    ///   - shakeToToggleButton: Whether shaking the device toggles button visibility. Defaults to `true`.
    ///   - onDismiss: Optional closure called when the panel is dismissed.
    @available(iOS 16.0, *)
    public static func install(
        store: TweakStore,
        tabs: [TweakTab] = [],
        buttonIcon: String = "slider.vertical.3",
        buttonInitiallyVisible: Bool = true,
        shakeToToggleButton: Bool = true,
        onDismiss: (() -> Void)? = nil
    ) {
        #if DEBUG
        let manager = TweakPanelWindowManager(
            store: store,
            tabs: tabs,
            buttonIcon: buttonIcon,
            buttonInitiallyVisible: buttonInitiallyVisible,
            shakeToToggleButton: shakeToToggleButton,
            onDismiss: onDismiss
        )
        manager.setup()
        windowManager = manager
        #endif
    }

    /// The button state, for toggling visibility from UIKit code.
    #if DEBUG
    @available(iOS 16.0, *)
    public static var buttonState: TweakPanelButtonState? {
        return windowManager?.buttonState
    }
    #endif

    /// Programmatically presents the tweak panel.
    ///
    /// - Parameter selectingTab: Optional tab name to select on presentation.
    ///   When `nil`, the panel restores the last-used tab.
    @available(iOS 16.0, *)
    public static func present(selectingTab: String? = nil) {
        #if DEBUG
        windowManager?.presentPanel(selectingTab: selectingTab)
        #endif
    }

    /// Creates a `UIWindow` subclass with a two-finger double-tap gesture that opens the panel.
    ///
    /// Use this as your app's main window if you want the gesture shortcut:
    /// ```swift
    /// window = TweakPanel.makeWindow(frame: UIScreen.main.bounds)
    /// ```
    @available(iOS 16.0, *)
    public static func makeWindow(frame: CGRect) -> UIWindow {
        #if DEBUG
        return TweakGestureWindow(frame: frame)
        #else
        return UIWindow(frame: frame)
        #endif
    }

    /// Creates a `UIWindow` subclass with a two-finger double-tap gesture that opens the panel.
    @available(iOS 16.0, *)
    public static func makeWindow(windowScene: UIWindowScene) -> UIWindow {
        #if DEBUG
        return TweakGestureWindow(windowScene: windowScene)
        #else
        return UIWindow(windowScene: windowScene)
        #endif
    }
}

// MARK: - Gesture Window

#if DEBUG
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
#endif
