# UI Interaction & Accessibility Audit

> Trinket follows the visual-first baseline in PD-007. This audit checks native control interaction and visible UI clarity; it does not require comprehensive accessibility support or platform accessibility audits.

**Goal:** Find confirmed interaction, feedback, and accessibility defects that static types do not catch.

## Intent

Fix confirmed navigation/feedback/accessibility defects across flows. Reuse existing UI coverage; do not add a test unless the Testing rubric identifies a unique shipping journey or safety invariant. Significant shared patterns remain proposals per [README.md](README.md).

## Hard stops

- Do not restyle unrelated chrome or expand into layout/typography/DesignSystem migrations (AppleNativeUI owns those).
- iPhone portrait-first; skip iPad-only hover work unless product scope expands.
- Do not expand a selected-flow check into a full-tab manual pass; skip unavailable Simulator/device checks without failing the audit.
- Do not expand into UI test rewrites (E2E owns those).

## Domain rules

**Navigation & modals:** `TabView` top-level only; `NavigationStack` per tab; every sheet/cover has a dismiss path; destructive actions use confirmation + cancel.

**Gestures:** scroll/drag/modal modes must not fight; `DragGesture` `.updating` resets on cancel/end; long-press must not block tap navigation.

**Feedback:** interactive elements are `Button`s (preferred) or gestures with visible feedback; long `Task` work shows progress; victory/defeat screens always dismissible.

**Accessibility baseline:** retain visible control labels and native SwiftUI control behavior, plus stable `accessibilityIdentifier` values for UI tests. Do not add custom labels, hints, values, grouping, traits, accessibility-setting branches, or audit requirements unless PD-007 is revisited.

**Edge cases:** rapid-tap debounce on stage start / craft / reward claim; battle pauses on `scenePhase` background; keyboard dismissal where applicable; empty states for empty collection/inventory/homestead.

## Evidence bar

Interactive flow missing a dismiss path, visible feedback, or stable identifier; gesture fight; or double-trigger on a primary action.
