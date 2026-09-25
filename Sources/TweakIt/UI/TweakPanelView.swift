//
//  TweakPanelView.swift
//  TweakIt
//
//  Root container view — tabbed when custom tabs are provided, single tweaks browser otherwise.
//

import SwiftUI

// MARK: - Disable Interactive Pop Gesture

/// Prevents the NavigationStack's swipe-back gesture from firing when
/// the user drags sliders near the screen edge (especially at min/max values).
/// Navigation still works via the nav bar back button and the "Done" dismiss button.
@available(iOS 16.0, *)
private struct DisableInteractivePopGesture: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        DisablePopGestureVC()
    }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}

private class DisablePopGestureVC: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
}

// MARK: - Panel View

/// Root view for the tweak panel.
///
/// When custom tabs are provided, shows a segmented picker at the top.
/// When no tabs are provided, shows just the tweaks browser.
///
/// - Note: The panel follows the system appearance and every colour in it is semantic. It used to
///   force `.preferredColorScheme(.dark)`, which only darkened the SwiftUI environment — the sheet
///   chrome around it is UIKit (Liquid Glass on iOS 26) and kept following the system, so a
///   light-mode device got white text on light glass. Don't reintroduce that, and don't "fix" it
///   from the other end with `overrideUserInterfaceStyle` on the hosting controller either: a debug
///   panel has no business overriding the user's appearance setting.
@available(iOS 16.0, *)
struct TweakPanelView: View {
    let store: TweakStore
    let tabs: [TweakTab]
    let onDismiss: (() -> Void)?
    var willDismiss: (() -> Void)? = nil

    @AppStorage("TweakIt.lastTab") private var selectedTabIndex: Int = 0
    @Environment(\.dismiss) private var dismiss

    /// All tab names including the built-in "Tweaks" tab.
    private var allTabNames: [String] {
        var names = ["Tweaks"]
        names.append(contentsOf: tabs.map(\.name))
        return names
    }

    private var allTabIcons: [String] {
        var icons = ["slider.vertical.3"]
        icons.append(contentsOf: tabs.map(\.icon))
        return icons
    }

    /// The panel's dismiss control.
    ///
    /// A close, not a cancel. Tweaks apply the instant you touch them, so dismissing the panel
    /// discards nothing — which is exactly the line Apple draws between the two roles. Saying
    /// `.close` rather than hard-coding a label is what lets the system render the standard X
    /// and place it per device; on iPhone Duo that means the top of the vertical bar.
    ///
    /// The close role is iOS 26+. Older systems keep the "Done" label, which is fine — none of
    /// them run on hardware that lays the bar out any differently.
    @ViewBuilder
    private var dismissButton: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close) { performDismiss() }
        } else {
            Button("Done") { performDismiss() }
        }
    }

    private func performDismiss() {
        willDismiss?()
        onDismiss?()
        dismiss()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Only show segmented picker if there are custom tabs
                if !tabs.isEmpty {
                    Picker("Panel", selection: $selectedTabIndex) {
                        ForEach(0..<allTabNames.count, id: \.self) { index in
                            Label(allTabNames[index], systemImage: allTabIcons[index])
                                .labelStyle(.iconOnly)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }

                // Content
                if tabs.isEmpty || selectedTabIndex == 0 {
                    TweaksListView(store: store)
                } else {
                    let tabIndex = selectedTabIndex - 1
                    if tabIndex >= 0 && tabIndex < tabs.count {
                        tabs[tabIndex].content()
                    }
                }
            }
            .background(DisableInteractivePopGesture())
            .navigationTitle(tabs.isEmpty ? "Tweaks" : "Dev Tools")
            .navigationBarTitleDisplayMode(.inline)
            .disablingVerticalToolbar()
            .toolbar {
                // Semantic placements, not `.navigationBar{Leading,Trailing}`. A positional
                // placement pins the item to a screen edge; the semantic ones tell the system
                // what the button *is*, so it can put the dismiss and overflow controls where
                // that device's bar wants them. iPhone Duo is the case that forced this:
                // Apple's guidance is that close buttons go in `.cancellationAction`, which
                // the system hoists to the top of the Duo's vertical bar.
                ToolbarItem(placement: .cancellationAction) {
                    dismissButton
                }
                if tabs.isEmpty || selectedTabIndex == 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(role: .destructive) {
                                store.storage.resetAll()
                            } label: {
                                Label("Reset All to Defaults", systemImage: "arrow.counterclockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Vertical Toolbar Opt-Out

private extension View {
    /// Keeps the panel's toolbar horizontal on iPhone Duo (iOS 27.1+).
    ///
    /// Duo moves a sheet's toolbar onto a vertical bar down the side of the sheet, which costs
    /// width a control-heavy panel can't spare — this one is a segmented picker over dense rows
    /// of sliders and switches. Apple's opt-out for exactly that case is
    /// `toolbarVerticalBehavior(.disabled)`, which leaves the dismiss button in the sheet's
    /// top corner and gives the content the full width back.
    ///
    /// The modifier exists only in the iOS 27.1 SDK, so the guard has to ask which SwiftUI it's
    /// compiling against. `#if compiler(...)` can't: Xcode 27.0 and 27.1 ship the same Swift 6.4,
    /// and the 27.0 SDK has no such modifier. SwiftUI's module version does move — 8.0.84 in the
    /// 27.0 SDK, 8.0.85 in 27.1 — and Xcode 26's is lower still, so every older SDK compiles the
    /// plain `self` branch.
    @ViewBuilder
    func disablingVerticalToolbar() -> some View {
        #if canImport(SwiftUI, _version: 8.0.85) // iOS 27.1 SDK and up
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(.disabled)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
