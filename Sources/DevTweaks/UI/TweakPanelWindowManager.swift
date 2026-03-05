//
//  TweakPanelWindowManager.swift
//  DevTweaks
//
//  Manages the floating button window and panel presentation window.
//

#if DEBUG
import UIKit
import SwiftUI

/// Manages the floating button window and the panel presentation window.
///
/// Created and owned by `TweakPanel.install()`. Not a singleton — each install creates one.
@available(iOS 16.0, *)
final class TweakPanelWindowManager: NSObject {
    let store: TweakStore
    let tabs: [TweakTab]
    let onDismiss: (() -> Void)?
    let buttonIcon: String
    let shakeToToggleButton: Bool

    let buttonState: TweakPanelButtonState

    private var buttonWindow: PassThroughWindow?
    private var panelWindow: UIWindow?
    private var sceneObserver: NSObjectProtocol?

    init(
        store: TweakStore,
        tabs: [TweakTab],
        buttonIcon: String,
        buttonInitiallyVisible: Bool,
        shakeToToggleButton: Bool,
        onDismiss: (() -> Void)?
    ) {
        self.store = store
        self.tabs = tabs
        self.buttonIcon = buttonIcon
        self.shakeToToggleButton = shakeToToggleButton
        self.onDismiss = onDismiss
        self.buttonState = TweakPanelButtonState(initiallyVisible: buttonInitiallyVisible)
        super.init()
    }

    /// Sets up both windows. Safe to call from `didFinishLaunchingWithOptions` —
    /// if no window scene is connected yet, setup defers until one activates.
    func setup() {
        if shakeToToggleButton {
            UIWindow.devTweaks_enableShakeToToggle()
        }

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            // Scene not ready yet — defer until one activates
            sceneObserver = NotificationCenter.default.addObserver(
                forName: UIScene.didActivateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                if let observer = self?.sceneObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.sceneObserver = nil
                }
                self?.setup()
            }
            return
        }

        // Prevent double-setup if called again from the deferred observer
        guard buttonWindow == nil else { return }

        // Button window (always visible, touch-transparent)
        let btnWin = PassThroughWindow(frame: UIScreen.main.bounds)
        btnWin.windowScene = scene
        btnWin.windowLevel = UIWindow.Level.normal + 9
        btnWin.backgroundColor = .clear

        let container = TweakPanelButtonContainer(state: buttonState, icon: buttonIcon) { [weak self] in
            self?.presentPanel()
        }
        let hostingController = UIHostingController(rootView: container)
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false
        btnWin.rootViewController = hostingController
        btnWin.isHidden = false
        self.buttonWindow = btnWin

        // Panel window (hidden until presented)
        let pnlWin = UIWindow(frame: UIScreen.main.bounds)
        pnlWin.windowScene = scene
        pnlWin.windowLevel = UIWindow.Level.normal + 10
        pnlWin.backgroundColor = .clear
        pnlWin.isHidden = true
        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .clear
        pnlWin.rootViewController = rootVC
        self.panelWindow = pnlWin
    }

    /// Presents the tweak panel as a sheet.
    func presentPanel(selectingTab tabName: String? = nil) {
        guard let panelWindow, let rootVC = panelWindow.rootViewController else { return }
        if rootVC.presentedViewController != nil { return }

        // Write tab selection to UserDefaults BEFORE creating the view,
        // so @AppStorage("DevTweaks.lastTab") initializes with the correct value.
        if let tabName {
            var allTabNames = ["Tweaks"]
            allTabNames.append(contentsOf: tabs.map(\.name))
            if let index = allTabNames.firstIndex(of: tabName) {
                UserDefaults.standard.set(index, forKey: "DevTweaks.lastTab")
            }
        }

        let panelView = TweakPanelView(store: store, tabs: tabs, onDismiss: onDismiss)
        let hostingController = UIHostingController(rootView: panelView)
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .medium
            sheet.prefersGrabberVisible = true
            sheet.delegate = self
        }

        panelWindow.isHidden = false
        rootVC.present(hostingController, animated: true)
    }
}

@available(iOS 16.0, *)
extension TweakPanelWindowManager: UISheetPresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        panelWindow?.isHidden = true
        onDismiss?()
    }
}

// MARK: - Shake Detection

extension UIWindow {
    private static var _devTweaksShakeSwizzled = false

    /// Swizzles `motionEnded` on UIWindow to detect device shakes.
    /// Idempotent — safe to call multiple times.
    static func devTweaks_enableShakeToToggle() {
        guard !_devTweaksShakeSwizzled else { return }
        _devTweaksShakeSwizzled = true

        let original = #selector(UIWindow.motionEnded(_:with:))
        let swizzled = #selector(UIWindow.devTweaks_motionEnded(_:with:))

        guard let originalMethod = class_getInstanceMethod(UIWindow.self, original),
              let swizzledMethod = class_getInstanceMethod(UIWindow.self, swizzled)
        else { return }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc private func devTweaks_motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        // Call original implementation (method is swizzled, so this calls the real motionEnded)
        devTweaks_motionEnded(motion, with: event)

        if motion == .motionShake {
            if #available(iOS 16.0, *) {
                TweakPanel.buttonState?.toggle()
            }
        }
    }
}
#endif
