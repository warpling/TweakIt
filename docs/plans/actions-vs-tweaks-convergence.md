# Closing the gap between the Actions panel and the Tweaks panel

**Written 2026-09-08**, out of a Blackbox session where two debug toggles had to move from the host
app's hand-rolled Actions panel into TweakIt, and the move cost something. Not scheduled — this is a
note so the reasoning isn't re-derived later.

## The complaint

> "Toggles like that really don't belong in the actions panel. I prefer to have them grouped in
> tweaks." … "perhaps we need to rethink tweaks panel sometime because I find this way too
> complicated. Might be nice to revisit this sometime so there's less difference between the two
> panels."

Blackbox runs two debug surfaces side by side: TweakIt's generated panel, and `ActionsView`, a
hand-written SwiftUI `List` in the app. Things end up in the wrong one, and not only for taste
reasons — there are two concrete capability gaps that make the wrong panel the *only* panel for
certain jobs.

## Gap 1 — a tweak can't run a side effect when it changes

The real blocker. In the app, `ActionsView`'s toggles could do this:

```swift
ActionRow(title: forced ? "Force …: ON" : "Force …: OFF") {
    forced.toggle()
    Eligibility.setForce(forced)
    GameModel.gatekeeper()?.setNeedsToRecalculateProgress()   // ← the part TweakIt can't do
    NotificationCenter.default.post(name: .shareSuccessful, object: nil)
}
```

`TweakDefinition` has no per-key change hook, so the same toggle in TweakIt sets the value and
nothing else happens. The two flags that moved (`forceRewardDrip`, `ignoreEngagedFloor`) both drive
state that a live view has already computed, so flipping them now leaves the screen stale until some
unrelated recalculation happens to run. Each needed a "⚠️ this does not refresh a grid that's already
on screen" caveat in its doc comment, which is a design smell in a debug tool: the affordance
promises immediacy and doesn't deliver.

**Most of the machinery already exists.** `TweakStorage` is an `ObservableObject` and already sends
`objectWillChange` from `setValue` (and from the modified-keys path — `22187ac`). What's missing is
*which key changed*, and a place to hang a reaction.

Sketches, cheapest first:

1. **A key-carrying publisher on `TweakStorage`** — `didChange: AnyPublisher<String, Never>` emitting
   the changed key *after* the write. Fully backwards compatible; hosts filter for keys they care
   about. Callers still have to wire up a subscription somewhere sensible, which is boilerplate.
2. **`onChange:` on `TweakDefinition`** — `TweakDefinition("x", default: false, onChange: { _ in … })`.
   The nicest call site by far: the reaction sits next to the declaration, exactly like the existing
   `TweakDefinition("Label", action:)` button. Needs a decision on *when* it fires (panel edits only,
   or programmatic writes too — the latter is more honest and more surprising) and on retain
   semantics for a closure that outlives the panel.
3. Both — (1) as the mechanism, (2) as the sugar over it.

Prefer (2)'s ergonomics. It's the difference between a toggle that works and a toggle with a caveat.

## Gap 2 — actions and toggles for one feature can't sit together

A feature's debug surface is usually a few toggles *and* a couple of verbs ("reset this feature",
"simulate the event"). Today the nouns go in TweakIt and the verbs go in the host's own panel, so one
feature is split across two screens reached different ways.

TweakIt already has `TweakDefinition("Label", action: { … })`, so a section *can* host a button. What
it lacks is the presentation to make a mixed section read well — destructive styling, a visual break
between "settings" and "things that happen", and a way to disable a verb when a precondition isn't
met. Worth an audit of what `ActionsView` does that TweakIt can't express, and closing that list.

If both gaps close, the split becomes a genuine choice rather than a workaround, and arguably the
host-side panel stops needing to exist at all.

## Not in scope

- Redesigning the panel's visual language. The complaint is about capability and about one feature
  landing in two places, not about how a row looks.
- Migrating Blackbox's `ActionsView` wholesale. That follows the package work; doing it first just
  moves the caveats around.

## Where this came from

Blackbox, `Debug → Sharing`: `gateVariant`, `forceRewardDrip`, `ignoreEngagedFloor`. The share-reward
actions that stayed behind in `ActionsView` (Reset Share Count, Simulate Successful Share, Simulate
Blocked Fake-Share, Reset Timeline State) are exactly the "verbs" of Gap 2.
