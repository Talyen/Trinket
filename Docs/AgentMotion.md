# Agent Motion

Fluid motion and gesture feel for Trinket — **SwiftUI only**. Apply principles through `TrinketDesignSystem` / `TrinketMotion`, not web CSS, Pointer Events, or third-party spring libraries.

## Principles (short)

- **Response:** Feedback on press/drag start, not only on release. Avoid artificial delays on the input path.
- **Direct manipulation:** Dragged content tracks the finger 1:1; respect grab offset.
- **Interruptibility:** Animations must be redirectable mid-flight. Prefer springs (`.spring(response:dampingFraction:)`) over fixed-duration curves for anything the user can grab.
- **Behavior over choreography:** New input retargets the spring from the current presentation value — no jump back to a logical target.
- **Restraint:** Critically damped (`dampingFraction` ≈ 1.0) by default; bounce only when the gesture carried momentum.
- **Accessibility:** Honor Reduce Motion with shorter fades / simplified recipes already patterned in `TrinketMotion`.

## Where to implement

| Concern | Owner |
|---------|-------|
| Shared presets (battle, labyrinth, chips) | `Packages/TrinketDesignSystem/.../TrinketMotion.swift` |
| Surfaces, glass, typography | `TrinketDesign` / `.trinketSurface` / `.trinketMaterial` / `.trinketGlassChip` |
| Haptics gate | `.trinketSensoryFeedback(_:trigger:enabled:)` |
| Platform API notes | `Docs/Platform/iOS26AppleReference.md` |
| Chrome inventory | `Packages/TrinketDesignSystem/README.md` |

Prefer extending `TrinketMotion` (or a sibling preset enum in DesignSystem) over one-off durations in feature views. Dense Collection / Inventory surfaces stay on **solid** themed roles; glass belongs on chrome and selective overlays.

## Do not

- Load Cursor/web design skills or translate CSS/`requestAnimationFrame` patterns into the app.
- Hand-roll materials or button styles in `Features/` — route through DesignSystem (`./Scripts/check-ui-style.sh`).
- Lock out input for the full duration of a transition the user might reverse.
