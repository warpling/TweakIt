# Reading and Writing Values

Access tweak values with the store subscript or typed `TweakRef` handles.

## Overview

DevTweaks provides two ways to read tweak values: a generic subscript on ``TweakStore`` for quick access, and ``TweakRef`` for ergonomic typed handles with modification tracking.

## Store Subscript

The simplest way to read a value is the store's generic subscript:

```swift
let duration: CGFloat = AppTweaks.store["Animations.Spring.duration"]
let mockMode: Bool = AppTweaks.store["Debug.Network.mockMode"]
```

The type is inferred from the variable annotation and **must match** the type of the default value in your ``TweakDefinition``. A mismatch traps with a clear error message at runtime.

You can also write values through the subscript:

```swift
AppTweaks.store["Animations.Spring.duration"] = 0.5 as CGFloat
```

### Key Path Format

Keys follow the pattern `Category.Section.name`:

```
"Animations.Spring.duration"
 ──────────  ──────  ────────
  category   section   name
```

## TweakRef — Typed Handles

For frequently accessed tweaks, ``TweakRef`` gives you a typed handle that's easier to pass around and includes modification tracking:

```swift
enum AppTweaks {
    static let store = TweakStore { ... }

    // Type-inferred (requires type annotation):
    static let duration: TweakRef<CGFloat> = store.ref("Animations.Spring.duration")

    // Explicit type parameter:
    static let damping = store.ref("Animations.Spring.damping", as: CGFloat.self)
}
```

### Reading and Writing

```swift
let d = AppTweaks.duration.value     // current value (override or default)
AppTweaks.duration.value = 0.5       // persists override to UserDefaults
```

### Modification Tracking

```swift
AppTweaks.duration.isModified   // true if value differs from default
AppTweaks.duration.reset()      // revert to default
```

### Release Build Behavior

In release builds, ``TweakRef/value`` returns the compile-time default directly. The compiler can inline and constant-fold the result. See <doc:ReleaseBuildSafety> for details.

## Observing Changes

``TweakStorage`` conforms to `ObservableObject`. In SwiftUI, observe it to re-render when any tweak changes:

```swift
struct MyView: View {
    @ObservedObject private var storage = AppTweaks.store.storage

    var body: some View {
        let duration: CGFloat = AppTweaks.store["Animations.Spring.duration"]
        // view re-renders when any tweak value changes
    }
}
```

## Resetting Values

``TweakStorage`` provides granular reset methods:

```swift
let storage = AppTweaks.store.storage

// Reset a single tweak:
storage.reset(key: "Animations.Spring.duration")

// Reset all tweaks in a section:
storage.resetSection("Animations.Spring")

// Reset everything:
storage.resetAll()
```

The panel UI also supports swipe-to-reset on individual rows and a "Reset All" button per section.
