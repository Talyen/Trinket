# UI Interaction & Feedback Audit

Goal: Find interaction bugs types miss — broken navigation, stuck states, missing feedback, accessibility gaps, HIG / DesignSystem violations.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

1. Run code probes
2. Optionally exercise tabs in Simulator if available
3. Fix up to **5** clear issues
4. Verify style gate + smoke as needed
5. Commit

## Hard stops

- Do not restyle unrelated chrome.
- Do not change `accessibilityIdentifier` strings unless removing the control.
- Do not hand-roll materials/button styles — use `TrinketDesignSystem` (`./Scripts/check-ui-style.sh`).
- iPhone portrait-first; skip iPad-only hover work unless product scope expands.

## Probes

```bash
rg -n 'sheet|popover|fullScreenCover|alert|confirmationDialog|menu|contextMenu' --type swift -g '!*Tests*'
rg -n 'onTapGesture|onLongPressGesture|DragGesture|magnificationGesture' --type swift -g '!*Tests*'
rg -n '\.accessibilityIdentifier' --type swift
./Scripts/check-ui-style.sh
```

Manual (when Simulator available): Play, Collection (Heroes/Pets/Inventory), Homestead, Search, Options — plus one battle start/victory dismiss path.

## Checks

### Navigation & modals

- `TabView` top-level only; `NavigationStack` per tab
- Every sheet/cover has a dismiss path (`toolbar`, swipe, `Environment(\.dismiss)`)
- Destructive actions use confirmation + cancel
- No accidental stacked sheet+alert unless designed

### Gestures

- Scroll / drag / modal modes must not fight
- `DragGesture` `.updating` resets on cancel/end
- Long-press must not block tap navigation

### Tap feedback & loading

- Interactive elements are `Button`s (preferred) or gestures with visible feedback
- Route chrome through DesignSystem — **not** raw `.buttonStyle(.borderedProminent)` / `.glass` (flagged by `check-ui-style.sh`)
- Long `Task` work shows progress; victory/defeat screens always dismissible

### Accessibility

- Interactive controls have `accessibilityLabel` and/or `accessibilityIdentifier`
- Dynamic Type reflows without truncation
- Reduce Motion: respect `AccessibilityReduceMotion` / SwiftUI transaction disabling — **not** UIKit `UIView.animate` bridges
- Semantic colors from DesignSystem; no hardcoded text-on-background hex

### Portrait layout

- Works on large and small iPhones; primary actions thumb-reachable
- Lists/grids respect safe areas (tab bar / Dynamic Island)

### Edge cases

- Rapid tap debounce on stage start / craft / reward claim
- Battle pauses on `scenePhase` background
- Search fields: `.scrollDismissesKeyboard(.immediately)` or equivalent
- Empty states for empty collection/inventory/homestead

## Verification

```sh
./Scripts/check-ui-style.sh
./Scripts/lint.sh
./Scripts/test.sh smoke   # if identifiers or tab flows changed
```

## Commit

```
fix(ui): <imperative interaction fix>

- <what>
- check-ui-style + smoke as needed

User-Facing: yes
```
