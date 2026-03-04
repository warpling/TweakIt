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

    let buttonState: TweakPanelButtonState

    private var buttonWindow: PassThroughWindow?
    private var panelWindow: UIWindow?

    init(
        store: TweakStore,
        tabs: [TweakTab],
        buttonIcon: String,
        buttonInitiallyVisible: Bool,
        onDismiss: (() -> Void)?
    ) {
        self.store = store
        self.tabs = tabs
        self.buttonIcon = buttonIcon
        self.onDismiss = onDismiss
        self.buttonState = TweakPanelButtonState(initiallyVisible: buttonInitiallyVisible)
        super.init()
    }

    /// Sets up both windows. Call once after the app's main window is available.
    func setup() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

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
    func presentPanel() {
        guard let panelWindow, let rootVC = panelWindow.rootViewController else { return }
        if rootVC.presentedViewController != nil { return }

        let panelView = TweakPanelView(store: store, tabs: tabs, onDismiss: onDismiss)
        let hostingController = UIHostingController(rootView: panelView)
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.large()]
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
#endif
