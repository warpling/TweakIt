# Reading and Writing Values

Access tweak values with the store subscript or typed `TweakRef` handles.

## Overview

TweakIt provides two ways to read tweak values: a generic subscript on ``TweakStore`` for quick access, and ``TweakRef`` for ergonomic typed handles with modification tracking.

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

## Reading in a Hot Path

Reading a tweak every frame is fine. ``TweakStorage`` keeps values, the modified-key set, pins and
recents in memory: `UserDefaults` is written on every change and read once per key to warm the
cache, but is never consulted on a plain read. A read costs a lock, a set lookup and a dictionary
lookup.

This wasn't always true, and the failure was severe. Before 1.2.0 every read reached
`UserDefaults`, and `CFPreferences` `os_log`s the value it returns — including the whole
modified-key array, stringified in full. An app reading a few tweaks per frame spent its time
inside logging, stopped responding, and was killed by the iOS watchdog (`0x8BADF00D`). If you are
on 1.1.1 or earlier, upgrade.

Two habits are still worth keeping:

```swift
// Hoist the read out of the inner loop.
let radius = AppTweaks.blurRadius.value
for particle in particles { particle.blur(radius) }

// Writing a value the tweak already holds is dropped — no write, no `objectWillChange` —
// so a per-frame write of an unchanged value costs nothing but the comparison.
AppTweaks.blurRadius.value = computed
```

### Storage Owns Its Keys

``TweakStorage`` is a write-through cache, so it assumes it is the only writer of the keys under
its prefix. Writing one of those keys behind its back — seeding values from a config file,
`removePersistentDomain(forName:)`, or a second ``TweakStorage`` over the same defaults and
prefix — is invisible to it until you call ``TweakStorage/reloadFromDisk()``:

```swift
UserDefaults.standard.set(0.9, forKey: "TweakIt.Animations.Spring.damping")
AppTweaks.store.storage.reloadFromDisk()   // drop the caches, re-read, notify observers
```

Prefer routing the write through storage in the first place — `store["Animations.Spring.damping"] = 0.9`
keeps the cache correct with no extra step.

### Threading

Every member of ``TweakStorage`` is safe to call from any thread. `objectWillChange` is sent from
whichever thread made the change, so make changes on the main thread while the panel is on screen.

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

Resetting is not the same as ``TweakStorage/reloadFromDisk()``: a reset *changes* values, dropping
overrides so defaults apply again, while `reloadFromDisk()` changes nothing and only re-reads what
is already on disk.

The panel UI also supports swipe-to-reset on individual rows and a "Reset All" button per section. Swiping a row the other way pins it, floating a live copy of the control into the panel's Quick Access section so you don't have to navigate back to it. Pins survive both kinds of reset — a pin says "I'm working on this", not "this is modified".
