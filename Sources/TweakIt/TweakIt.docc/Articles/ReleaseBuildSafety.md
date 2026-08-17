# Release Build Safety

TweakIt is fully inert in release builds by default.

## Overview

The library is designed so that your shipping binary pays zero cost for debug tweaks. When ``TweakIt/isEnabled`` is `false` (the default in non-debug builds), all UI installation no-ops and all value access through ``TweakRef`` returns defaults directly.

## What Happens When TweakIt Is Disabled

| API | Behavior when disabled |
|---|---|
| ``TweakPanel/install(store:tabs:buttonIcon:buttonInitiallyVisible:buttonBottomOffset:shakeToToggleButton:onDismiss:)`` | No-op |
| ``TweakPanel/install(store:tabs:buttonAlignment:buttonInset:buttonIgnoresSafeAreaEdges:buttonInitiallyVisible:shakeToToggleButton:onDismiss:button:)`` | No-op |
| ``TweakPanel/present(selectingTab:)`` | No-op |
| ``TweakPanel/makeWindow(windowScene:)`` | Returns a standard `UIWindow` |
| ``TweakPanel/buttonState`` | Returns `nil` |
| ``TweakRef/value`` (getter) | Returns the compile-time default |
| ``TweakRef/value`` (setter) | No-op |
| ``TweakRef/isModified`` | Returns `false` |
| ``TweakRef/reset()`` | No-op |
| ``TweakStorage`` read/write/reset methods | No-op / return defaults |

## How It Works

TweakIt uses a single runtime toggle — ``TweakIt/isEnabled`` — to gate all functionality:

- In `DEBUG` builds, `isEnabled` defaults to `true`.
- In all other builds, `isEnabled` defaults to `false`.

Every public entry point checks this flag and short-circuits when disabled. The UI types still exist in the binary but are never instantiated, so the runtime cost is effectively zero.

### Value Layer — Runtime Guards

``TweakRef/value`` checks `isEnabled` internally:

```swift
public var value: T {
    get {
        guard TweakIt.isEnabled else { return defaultValue }
        return storage.value(forKey: key, default: defaultValue)
    }
}
```

When disabled, the getter is a simple return of a stored constant.

## Recommended Pattern

```swift
#if DEBUG
TweakPanel.install(store: AppTweaks.store)
#endif
```

The ``TweakStore`` DSL and ``TweakStorage`` are available in all builds, so you can define your store unconditionally. Only the UI presentation layer needs to be gated.

## Using TweakIt in Non-Debug Builds

To enable TweakIt in a release-optimized build (e.g., for internal testing or TestFlight), set ``TweakIt/isEnabled`` to `true` before calling `install()`:

```swift
#if INTERNAL
TweakIt.isEnabled = true
#endif
TweakPanel.install(store: AppTweaks.store)
```

Since `isEnabled` is a runtime flag set in your app's own code, it works regardless of build configuration or SPM limitations — no special compiler flags needed on the TweakIt package itself.

A common setup:

| Build Config | App Compilation Conditions | TweakIt Active | Use For |
|---|---|---|---|
| Debug | `DEBUG` | Yes (default) | Development |
| Internal | `INTERNAL` | Yes (opt-in) | Device testing, internal TestFlight |
| Release | *(none)* | No | App Store |

## Store Subscript in Release Builds

Note that the ``TweakStore`` subscript reads from ``TweakStorage`` in all builds (it doesn't have a runtime guard internally). If you use the subscript in release builds, it will read from UserDefaults. For zero-overhead release access, prefer ``TweakRef``:

```swift
// Subscript — reads UserDefaults in all builds:
let duration: CGFloat = AppTweaks.store["Animations.Spring.duration"]

// TweakRef — returns default directly when disabled:
let duration = AppTweaks.duration.value
```

For most apps, the UserDefaults read is negligible. Use ``TweakRef`` when you want the guarantee.
