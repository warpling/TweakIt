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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        willDismiss?()
                        onDismiss?()
                        dismiss()
                    }
                }
                if tabs.isEmpty || selectedTabIndex == 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
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
