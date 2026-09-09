# Defining Tweaks

Use the result builder DSL to declare tweakable parameters.

## Overview

Tweaks are organized in a three-level hierarchy: **categories** contain **sections**, and sections contain individual **tweak definitions**. The UI control for each tweak is inferred automatically from its default value and parameters.

## Hierarchy

```
TweakStore
 └─ TweakCategory("Visual", icon: "eye")
     └─ TweakSection("Animations")
         ├─ TweakDefinition("enabled", default: true)
         └─ TweakGroup("Spring")
             ├─ TweakDefinition("duration", default: 0.46, range: 0.1...2.0)
             └─ TweakDefinition("damping", default: 0.8, range: 0.1...1.0)
```

Key paths follow the pattern `Category.Section.name` — for example, `"Visual.Animations.duration"`. ``TweakGroup`` is a fourth, purely visual level: it adds a sub-heading in the panel and contributes nothing to the key.

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

## Action Buttons

Unlike other tweaks, action definitions don't store a value. They render as a tappable button that fires a closure — useful for debug shortcuts like resetting state, clearing caches, or triggering test events:

```swift
TweakCategory("Debug", icon: "ladybug") {
    TweakSection("Actions") {
        TweakDefinition("Reset Onboarding", action: {
            UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
        })
        TweakDefinition("Crash (Test)", action: {
            fatalError("Test crash from TweakIt")
        })
        TweakDefinition("Clear Image Cache", action: {
            ImageCache.shared.removeAll()
        })
    }
}
```

Action buttons can live alongside regular tweaks in the same section. They appear as tappable rows in the panel UI.

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

### Groups

A long section stops being scannable somewhere around a dozen rows. ``TweakGroup`` breaks it up with sub-headings, replacing the `// — Shape —` source comments the panel could never see:

```swift
TweakSection("Modal Cards") {
    TweakDefinition("enabled", default: true)

    TweakGroup("Shape") {
        TweakDefinition("cornerRadius", default: 12.0, range: 0...40)
        TweakDefinition("shadowRadius", default: 8.0, range: 0...40)
    }

    TweakGroup("Physics") {
        TweakDefinition("gravity", default: 1.0, range: 0...4)
    }
}
```

Each group becomes its own headed block in the panel, in declaration order. Tweaks declared bare — `enabled` above — form an implicit *ungrouped run* that renders with no heading at all, and a section can hold several of them interleaved with groups, so loose tweaks can sit both above and below a group.

Two things worth knowing:

- **The group name is not part of the storage key.** `cornerRadius` is `"Visual.Modal Cards.cornerRadius"` whether or not it sits in a group, so grouping an existing section never resets values already dialled in on a device.
- **Groups don't nest.** A ``TweakGroup`` declared inside another is flattened into its parent rather than producing a second level of heading.

Reading the structure back, ``TweakSectionMetadata/groups`` gives the declared shape (with `nil` names for the ungrouped runs), while ``TweakSectionMetadata/tweaks`` stays a flat list across all of them.

### Descriptions

Every ``TweakDefinition`` initializer takes a trailing `description:` — a one-line gloss shown under the name in small monospaced text:

```swift
TweakSection("Sharing") {
    TweakDefinition("ignoreEngagedFloor", default: false,
                    description: "skip the 3-solve minimum before the share prompt")
    TweakDefinition("rewardDrip", default: 2, range: 1...10,
                    description: "shares between reward reveals")
}
```

Use it when the name alone won't survive six months. Keep it to a phrase — the panel renders it as a caption, not a paragraph. A tweak without a description renders exactly as it did before descriptions existed.

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
