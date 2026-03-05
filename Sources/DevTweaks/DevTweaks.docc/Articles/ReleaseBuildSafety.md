# Release Build Safety

DevTweaks compiles away completely in release builds.

## Overview

The library is designed so that your shipping binary pays zero cost for debug tweaks. All UI code is gated behind `#if DEBUG`, and value access through ``TweakRef`` returns compile-time constants in release builds.

## What Happens in Release Builds

| API | Release behavior |
|---|---|
| ``TweakPanel/install(store:tabs:buttonIcon:buttonInitiallyVisible:onDismiss:)`` | No-op |
| ``TweakPanel/present(selectingTab:)`` | No-op |
| ``TweakPanel/makeWindow(windowScene:)`` | Returns a standard `UIWindow` |
| ``TweakPanel/buttonState`` | Returns `nil` |
| ``TweakRef/value`` (getter) | Returns the compile-time default |
| ``TweakRef/value`` (setter) | No-op |
| ``TweakRef/isModified`` | Returns `false` |
| ``TweakRef/reset()`` | No-op |
| ``TweakStorage`` read/write/reset methods | No-op / return defaults |

## How It Works

The library uses two layers of compile-time gating:

### UI Layer — `#if DEBUG`

All panel UI code — windows, buttons, hosting controllers, SwiftUI views — is wrapped in `#if DEBUG` blocks. In release builds, these types don't exist in the binary at all.

### Value Layer — Inlineable Defaults

``TweakRef/value`` checks `#if DEBUG` internally:

```swift
public var value: T {
    get {
        #if DEBUG
        return storage.value(forKey: key, default: defaultValue)
        #else
        return defaultValue
        #endif
    }
}
```

In release builds, the getter is a simple return of a stored constant. The compiler can inline this and constant-fold the result, making it equivalent to using a literal value.

## Recommended Pattern

Wrap your ``TweakPanel/install(store:tabs:buttonIcon:buttonInitiallyVisible:onDismiss:)`` call in `#if DEBUG` so it's clear at the call site:

```swift
#if DEBUG
TweakPanel.install(store: AppTweaks.store)
#endif
```

The ``TweakStore`` DSL and ``TweakStorage`` are available in all builds, so you can define your store unconditionally. Only the UI presentation layer needs the `#if DEBUG` guard.

## Store Subscript in Release Builds

Note that the ``TweakStore`` subscript reads from ``TweakStorage`` in all builds (it doesn't have `#if DEBUG` gating internally). If you use the subscript in release builds, it will read from UserDefaults. For zero-overhead release access, prefer ``TweakRef``:

```swift
// Subscript — reads UserDefaults in all builds:
let duration: CGFloat = AppTweaks.store["Animations.Spring.duration"]

// TweakRef — returns default directly in release builds:
let duration = AppTweaks.duration.value
```

For most apps, the UserDefaults read is negligible. Use ``TweakRef`` when you want the guarantee.
