# Defining Tweaks

Use the result builder DSL to declare tweakable parameters.

## Overview

Tweaks are organized in a three-level hierarchy: **categories** contain **sections**, and sections contain individual **tweak definitions**. The UI control for each tweak is inferred automatically from its default value and parameters.

## Hierarchy

```
TweakStore
 └─ TweakCategory("Visual", icon: "eye")
     └─ TweakSection("Animations")
         ├─ TweakDefinition("duration", default: 0.46, range: 0.1...2.0)
         └─ TweakDefinition("enabled", default: true)
```

Key paths follow the pattern `Category.Section.name` — for example, `"Visual.Animations.duration"`.

## Control Types

The control type is inferred from the default value and any additional parameters:

| Definition | Control |
|---|---|
| `TweakDefinition("flag", default: true)` | Toggle |
| `TweakDefinition("speed", default: 0.5, range: 0.0...1.0)` | Slider (Double) |
| `TweakDefinition("speed", default: CGFloat(0.5), range: 0.0...1.0)` | Slider (CGFloat) |
| `TweakDefinition("columns", default: 3)` | Stepper |
| `TweakDefinition("columns", default: 3, range: 1.0...10.0)` | Integer slider |
| `TweakDefinition("name", default: "hello")` | Text field |
| `TweakDefinition("env", default: "prod", options: ["prod", "staging"])` | Picker |
| `TweakDefinition("reset", action: { ... })` | Action button |

- **Bool** defaults produce a toggle switch.
- **Double** or **CGFloat** defaults with a range produce a continuous slider.
- **Int** defaults without a range produce a stepper (+/- buttons). With a range, they produce a stepped slider.
- **String** defaults produce a text field. Add an `options` array to get a segmented picker instead.
- **Action** tweaks have no stored value — they fire a closure on tap.

## Categories

A ``TweakCategory`` groups related sections under a collapsible header with an SF Symbol icon:

```swift
TweakCategory("Visual", icon: "eye") {
    // sections go here
}
```

## Sections

A ``TweakSection`` groups related tweak definitions within a category:

```swift
TweakSection("Spring") {
    TweakDefinition("duration", default: 0.46, range: 0.1...2.0)
    TweakDefinition("damping", default: 0.8, range: 0.1...1.0)
}
```

### Master Toggles

A section can have a master toggle that enables or disables all its tweaks at once:

```swift
TweakSection("Feature Flags", hasMasterToggle: true) {
    TweakDefinition("newUI", default: false)
    TweakDefinition("darkMode", default: true)
}
```

Query the toggle state with ``TweakStore/isSectionEnabled(_:)``:

```swift
if AppTweaks.store.isSectionEnabled("Debug.Feature Flags") {
    // section is enabled
}
```

### Metadata

Sections support optional `tag` and `color` properties for app-specific decoration. These values are available on ``TweakSectionMetadata`` and can be used when building custom tab views:

```swift
TweakSection("Rotation", hasMasterToggle: true, tag: ChallengeType.rotation, color: .blue) {
    TweakDefinition("easier", default: false)
}
```

## Result Builders

The DSL uses three result builders — ``TweakCategoryBuilder``, ``TweakSectionBuilder``, and ``TweakDefinitionBuilder`` — which support `if`/`else`, `if let`, and `for...in` for conditional and dynamic tweak definitions:

```swift
TweakStore {
    TweakCategory("Debug", icon: "ladybug") {
        TweakSection("Logging") {
            TweakDefinition("verbose", default: false)
        }

        if isInternalBuild {
            TweakSection("Internal") {
                TweakDefinition("crashOnError", default: false)
            }
        }
    }
}
```
