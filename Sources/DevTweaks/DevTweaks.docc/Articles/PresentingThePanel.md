# Presenting the Panel

Install, configure, and open the tweak panel.

## Overview

DevTweaks provides multiple ways to open the debug panel: a floating button, a two-finger double-tap gesture, and programmatic presentation. You can also add custom SwiftUI tabs alongside the built-in tweaks browser.

## Installing the Panel

Call ``TweakPanel/install(store:tabs:buttonIcon:buttonInitiallyVisible:onDismiss:)`` once after your app's main window is available:

```swift
#if DEBUG
TweakPanel.install(store: AppTweaks.store)
#endif
```

This creates two overlay windows:
- A **floating button** (bottom-left) that opens the panel on tap
- A **panel window** that presents the tweaks UI as a sheet

> Tip: In a pure SwiftUI app, `UIWindowScene` isn't available during `App.init()`. Defer the install call to the next run loop:
> ```swift
> init() {
>     DispatchQueue.main.async {
>         TweakPanel.install(store: AppTweaks.store)
>     }
> }
> ```

## Floating Button

The floating button is draggable and snaps to screen edges. Configure its initial visibility and icon:

```swift
TweakPanel.install(
    store: AppTweaks.store,
    buttonIcon: "gearshape",           // any SF Symbol
    buttonInitiallyVisible: false      // hidden by default
)
```

Control visibility at runtime through ``TweakPanel/buttonState``:

```swift
TweakPanel.buttonState?.isVisible = true
TweakPanel.buttonState?.toggle()  // animated
```

## Gesture Window

If you create your app's main `UIWindow` through ``TweakPanel/makeWindow(windowScene:)``, you get a two-finger double-tap gesture that opens the panel:

```swift
// In your SceneDelegate:
window = TweakPanel.makeWindow(windowScene: windowScene)
```

This returns a standard `UIWindow` in release builds.

## Programmatic Presentation

Open the panel from code with ``TweakPanel/present(selectingTab:)``:

```swift
// Open to the last-used tab:
TweakPanel.present()

// Open to a specific tab by name:
TweakPanel.present(selectingTab: "Actions")
```

This is useful for wiring up your own buttons or gestures.

## Custom Tabs

Add app-specific SwiftUI views as tabs alongside the built-in tweaks browser. Each ``TweakTab`` takes a name, SF Symbol icon, and a `@ViewBuilder` closure:

```swift
TweakPanel.install(
    store: AppTweaks.store,
    tabs: [
        TweakTab("Actions", icon: "bolt") { ActionsView() },
        TweakTab("Stats", icon: "chart.bar") { StatsView() },
    ]
)
```

Custom tabs appear before the built-in "Tweaks" tab in the segmented picker. You can use ``TweakPanel/present(selectingTab:)`` to open directly to a custom tab by name.

### Building a Per-Category Tab

A common pattern is to build a tab that shows the sections for a specific ``TweakCategoryMetadata`` from your store:

```swift
struct ShaderTabView: View {
    let categoryName: String
    @ObservedObject private var storage = AppTweaks.store.storage

    var body: some View {
        let category = AppTweaks.store.categories.first { $0.name == categoryName }
        List {
            if let category {
                ForEach(category.sections) { section in
                    NavigationLink {
                        TweakSectionDetailView(section: section, storage: storage)
                    } label: {
                        Text(section.name)
                    }
                }
            }
        }
    }
}
```

## Dismiss Callback

React to the panel being dismissed (e.g., to log analytics or refresh state):

```swift
TweakPanel.install(
    store: AppTweaks.store,
    onDismiss: {
        print("Panel dismissed")
    }
)
```
