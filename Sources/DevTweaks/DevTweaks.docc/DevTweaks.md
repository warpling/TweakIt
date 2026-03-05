# ``DevTweaks``

Runtime-adjustable debug parameters for iOS apps.

@Metadata {
    @DisplayName("DevTweaks")
}

## Overview

DevTweaks lets you define tweakable parameters once in a declarative Swift DSL and get a full debug panel for free. Drag sliders, flip toggles, pick from options — see changes in real time without a rebuild.

All UI code compiles away in release builds. Your shipping binary pays zero cost.

## Topics

### Essentials

- <doc:GettingStarted>
- ``TweakStore``
- ``TweakPanel``

### Defining Tweaks

- <doc:DefiningTweaks>
- ``TweakCategory``
- ``TweakSection``
- ``TweakDefinition``
- ``TweakCategoryBuilder``
- ``TweakSectionBuilder``
- ``TweakDefinitionBuilder``

### Reading and Writing Values

- <doc:ReadingValues>
- ``TweakRef``
- ``TweakStorage``

### Presenting the Panel

- <doc:PresentingThePanel>
- ``TweakTab``
- ``TweakPanelButtonState``

### Release Build Safety

- <doc:ReleaseBuildSafety>

### Metadata Types

- ``TweakMetadata``
- ``TweakSectionMetadata``
- ``TweakCategoryMetadata``
