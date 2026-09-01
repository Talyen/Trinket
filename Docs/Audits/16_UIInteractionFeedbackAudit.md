# 16. UI Interaction Audit

> Trinket ships basic accessibility semantics (PD-014). This audit covers interaction
> and feedback quality; it does not review accessibility accommodations.

**Goal:** Find confirmed interaction and feedback defects that static types do not catch.

## Intent

Fix confirmed navigation/feedback defects across flows. When a shared control or interaction pattern is implicated, inventory adjacent flows using it and fix the confirmed cluster. Reuse existing UI coverage; do not add a test unless the Testing rubric identifies a unique shipping journey or safety invariant.

## Hard stops

- Do not restyle unrelated chrome or expand into layout/typography/DesignSystem migrations (AppleNativeUI owns those).
- Do not add accessibility accommodation branches (Reduce Motion, Dynamic Type re-layout, or contrast modes). Keep image labels and hiding aligned with PD-014.
- iPhone portrait-first; skip iPad-only hover work unless product scope expands.
- Do not turn one candidate into an untriggered full-tab manual pass. Expand to adjacent flows only when they share the confirmed component, gesture, state machine, or primary-action invariant. Skip unavailable Simulator/device checks without failing the audit.
- Do not expand into UI test rewrites (E2E owns those).

## Domain rules

**Navigation & modals:** `TabView` top-level only; `NavigationStack` per tab; every sheet/cover has a dismiss path; destructive actions use confirmation + cancel.

**Gestures:** scroll/drag/modal modes must not fight; `DragGesture` `.updating` resets on cancel/end; long-press must not block tap navigation.

**Feedback:** interactive elements are `Button`s (preferred) or gestures with visible feedback; long `Task` work shows progress; victory/defeat screens always dismissible.

**Control states:** primary actions have coherent enabled, disabled, loading, success, error/retry, and cancellation behavior where applicable; focus and keyboard presentation do not hide required actions; interruptions/backgrounding return the flow to a usable state.

**Identifiers:** stable `accessibilityIdentifier` values exist for every flow the UI tests drive. Identifiers are test infrastructure, not accessibility — never remove or rename one without the Testing.md presentation-contract checks.

**Edge cases:** rapid-tap debounce on stage start / craft / reward claim; battle pauses on `scenePhase` background; keyboard dismissal where applicable; empty states for empty collection/inventory/homestead.

## Evidence bar

Interactive flow missing a dismiss path, visible feedback, stable identifier, required control state, focus/keyboard recovery, interruption recovery, or error/retry route; gesture fight; or double-trigger on a primary action. A shared-component fix includes every confirmed affected caller.

**Static vs runtime evidence:** missing dismiss paths, missing confirmation on destructive actions, missing `accessibilityIdentifier`s, non-`Button` interactive elements, missing rapid-tap debounce, and missing `scenePhase` handling are confirmable from source and may ship in an unattended pass. Gesture fights, feedback feel, and progress-indicator timing normally need a running app — without Simulator access, record them as candidates in the handoff (or `Proposals.md` when durable) rather than shipping speculative fixes.
