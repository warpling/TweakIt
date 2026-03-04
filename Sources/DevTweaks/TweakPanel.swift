//
//  TweakPanel.swift
//  DevTweaks
//
//  Public API for installing and presenting the tweak panel.
//

import UIKit
import SwiftUI

/// Public entry point for installing the DevTweaks UI into your app.
///
/// Call `install(store:)` once in your `AppDelegate` or `SceneDelegate` to set up:
/// - A floating button (bottom-left) that opens the panel
/// - A two-finger double-tap gesture on the main window
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
    /// - Parameters:
    ///   - store: The `TweakStore` containing all tweak definitions.
    ///   - tabs: Optional custom tabs to show alongside the tweaks browser.
    ///   - buttonIcon: SF Symbol name for the floating button. Defaults to `"slider.vertical.3"`.
    ///   - buttonInitiallyVisible: Whether the floating button starts visible. Defaults to `true`.
    ///   - onDismiss: Optional closure called when the panel is dismissed.
    @available(iOS 16.0, *)
    public static func install(
        store: TweakStore,
        tabs: [TweakTab] = [],
        buttonIcon: String = "slider.vertical.3",
        buttonInitiallyVisible: Bool = true,
        onDismiss: (() -> Void)? = nil
    ) {
        #if DEBUG
        let manager = TweakPanelWindowManager(
            store: store,
            tabs: tabs,
            buttonIcon: buttonIcon,
            buttonInitiallyVisible: buttonInitiallyVisible,
            onDismiss: onDismiss
        )
        manager.setup()
        windowManager = manager
        #endif
    }

    /// The button state, for toggling visibility from UIKit code.
    @available(iOS 16.0, *)
    public static var buttonState: TweakPanelButtonState? {
        #if DEBUG
        return windowManager?.buttonState
        #else
        return nil
        #endif
    }

    /// Programmatically presents the tweak panel.
    @available(iOS 16.0, *)
    public static func present() {
        #if DEBUG
        windowManager?.presentPanel()
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
