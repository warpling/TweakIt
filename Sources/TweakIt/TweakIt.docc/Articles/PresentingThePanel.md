# Presenting the Panel

Install, configure, and open the tweak panel.

## Overview

TweakIt provides multiple ways to open the debug panel: a floating button, a two-finger double-tap gesture, and programmatic presentation. You can also add custom SwiftUI tabs alongside the built-in tweaks browser.

## Installing the Panel

Call ``TweakPanel/install(store:tabs:buttonIcon:buttonInitiallyVisible:buttonBottomOffset:shakeToToggleButton:onDismiss:)`` once after your app's main window is available:

```swift
#if DEBUG
TweakPanel.install(store: AppTweaks.store)
#endif
```

> Tip: To include the panel in non-debug builds, set `TweakIt.isEnabled = true` before calling `install()`. See <doc:ReleaseBuildSafety>.

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

The built-in floating button is fixed bottom-leading with a 16pt inset. Configure its initial visibility and icon:

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

## Custom Button

If the built-in circle doesn't match your app's design system, supply your own with ``TweakPanel/install(store:tabs:buttonAlignment:buttonInset:buttonIgnoresSafeArea:buttonInitiallyVisible:shakeToToggleButton:onDismiss:button:)``. The package still owns the pass-through window, visibility state, shake-to-toggle, and presentation — you only supply appearance and placement:

```swift
TweakPanel.install(
    store: AppTweaks.store,
    buttonAlignment: .bottomLeading,
    buttonInset: 24,
    buttonIgnoresSafeArea: true
) { present in
    Button(action: present) {
        Image(systemName: "slider.vertical.3")
            .font(.system(size: 17, weight: .medium))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(.thinMaterial, in: Circle())
}
```

`buttonAlignment` pins the button to any corner (or edge), and `buttonInset` sets its distance from the container. By default that inset is measured from the safe area, which makes it impossible to line the button up with chrome anchored to the physical screen corner — set `buttonIgnoresSafeArea: true` to measure `buttonInset` from the physical edge instead, as in the example above.

> Important: The view you return becomes the tappable region — `TweakPanelButtonContainer` reports its frame, and the pass-through window claims exactly that frame for touches. Keep the returned view tight to the visible control (size and shape it with `.frame(...)`/`.contentShape(...)` on the control itself) rather than adding outer padding. A view like `MyButton().padding(.bottom, 60)` creates a 60pt transparent strip that swallows touches before they ever reach your app.

> Important: The `button` closure runs exactly once, at setup — the manager builds the erased view then and holds it. If the button's appearance needs to change later, back it with `@ObservedObject`/`@State` inside the returned view rather than reading mutable state captured by the closure; captured state outside SwiftUI's dependency graph will never be seen again.

> Tip: To suppress the button entirely and drive presentation yourself (e.g., from your own settings menu), pass `{ _ in EmptyView() }` — not `EmptyView()`, since `button` is a closure that receives the present action. The pass-through window is still created, but `EmptyView()` reports a zero frame, so it claims no touches. Call ``TweakPanel/present(selectingTab:)`` from wherever you want to open the panel instead.

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
