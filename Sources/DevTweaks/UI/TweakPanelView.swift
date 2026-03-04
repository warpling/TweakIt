//
//  TweakPanelView.swift
//  DevTweaks
//
//  Root container view — tabbed when custom tabs are provided, single tweaks browser otherwise.
//

#if DEBUG
import SwiftUI

/// Root view for the tweak panel.
///
/// When custom tabs are provided, shows a segmented picker at the top.
/// When no tabs are provided, shows just the tweaks browser.
@available(iOS 16.0, *)
struct TweakPanelView: View {
    let store: TweakStore
    let tabs: [TweakTab]
    let onDismiss: (() -> Void)?

    @AppStorage("DevTweaks.lastTab") private var selectedTabIndex: Int = 0
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
            .navigationTitle(tabs.isEmpty ? "Tweaks" : "Dev Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
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
        .preferredColorScheme(.dark)
    }
}
#endif
