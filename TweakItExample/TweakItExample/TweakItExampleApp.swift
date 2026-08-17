//
//  TweakItExampleApp.swift
//  TweakItExample
//
//  Created by Ryan McLeod on 3/4/26.
//

import SwiftUI
import TweakIt

@main
struct TweakItExampleApp: App {
    init() {
        let useFloating: Bool = DemoTweaks.store.storage.value(forKey: "App.Panel.useFloatingButton", default: false)
        // Defer to next run loop — UIWindowScene isn't available during App.init()
        DispatchQueue.main.async {
            TweakPanel.install(
                store: DemoTweaks.store,
                tabs: [
                    TweakTab("Plasma", icon: "waveform") { ShaderTabView(categoryName: "Plasma") },
                    TweakTab("Aurora", icon: "sparkles") { ShaderTabView(categoryName: "Aurora") },
                    TweakTab("Marble", icon: "water.waves") { ShaderTabView(categoryName: "Marble") },
                    TweakTab("Voronoi", icon: "hexagon") { ShaderTabView(categoryName: "Voronoi") },
                    TweakTab("Actions", icon: "bolt.fill") { ActionsTabView() },
                ],
                buttonAlignment: .bottomTrailing,
                buttonInset: 24,
                buttonInitiallyVisible: useFloating,
                onDismiss: {
                    print("✅ TweakPanel onDismiss fired")
                }
            ) { present in
                Button(action: present) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
