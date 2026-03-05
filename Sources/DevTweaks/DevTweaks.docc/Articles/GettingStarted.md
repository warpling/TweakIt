# Getting Started with DevTweaks

Add runtime-tweakable parameters to your app in three steps.

## Overview

DevTweaks gives you a debug panel that reads tweak definitions from a declarative DSL. You define your parameters once, and the library generates the appropriate controls (sliders, toggles, pickers, etc.) automatically.

## Install the Package

Add DevTweaks via Swift Package Manager:

```
https://github.com/warpling/DevTweaks.git
```

Or in your `Package.swift`:

```swift
.package(url: "https://github.com/warpling/DevTweaks.git", from: "0.1.0")
```

Requires iOS 16+ and Swift 5.9+. Zero external dependencies.

## Define Your Tweaks

Create a ``TweakStore`` using the result builder DSL. Organize tweaks into categories and sections:

```swift
import DevTweaks

enum AppTweaks {
    static let store = TweakStore {
        TweakCategory("Animations", icon: "sparkles") {
            TweakSection("Spring") {
                TweakDefinition("duration", default: 0.46, range: 0.1...2.0)
                TweakDefinition("damping", default: 0.8, range: 0.1...1.0)
            }
        }
        TweakCategory("Debug", icon: "ladybug") {
            TweakSection("Network") {
                TweakDefinition("mockMode", default: false)
                TweakDefinition("endpoint", default: "production",
                                options: ["production", "staging", "local"])
            }
        }
    }
}
```

See <doc:DefiningTweaks> for the full DSL reference.

## Install the Panel

Call ``TweakPanel/install(store:tabs:buttonIcon:buttonInitiallyVisible:onDismiss:)`` once during app launch:

```swift
#if DEBUG
TweakPanel.install(store: AppTweaks.store)
#endif
```

This adds a floating button and a two-finger double-tap gesture that both open the panel.

## Read Values at Runtime

Use the store's generic subscript anywhere in your code:

```swift
let duration: CGFloat = AppTweaks.store["Animations.Spring.duration"]
```

The key path follows the pattern `Category.Section.name`. The type is inferred from the variable annotation and must match the type of the default value in your definition.

Changes persist across app launches via UserDefaults.
