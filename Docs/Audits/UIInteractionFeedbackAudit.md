# UI Interaction & Feedback Audit

Goal: Find interaction bugs types miss — broken navigation, stuck states, missing feedback, accessibility gaps, HIG / DesignSystem violations.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

UI **test** speed/tier issues → [E2ETestQualityAudit.md](E2ETestQualityAudit.md).

## Mission

1. Run `./Scripts/check-ui-style.sh` (primary automated gate) and the code probes below
2. Triage: only chase missing dismiss, identifier gaps, style-gate failures, stuck loading, clear a11y gaps
3. Optionally exercise tabs in Simulator if available
4. Fix up to **5** clear issues
5. Verify style gate + smoke as needed
6. Commit

## Hard stops

- Do not restyle unrelated chrome.
- Do not change `accessibilityIdentifier` strings unless removing the control.
- Do not hand-roll materials/button styles — use `TrinketDesignSystem` (`./Scripts/check-ui-style.sh`).
- iPhone portrait-first; skip iPad-only hover work unless product scope expands.
- Do not expand into UI test rewrites (E2E audit owns those).
- Full-tab manual Simulator pass is **optional** — skip without failing in cloud agents.

## Probes

```bash
./Scripts/check-ui-style.sh

rg -n 'sheet|popover|fullScreenCover|alert|confirmationDialog|menu|contextMenu' --type swift -g '!*Tests*'
rg -n 'onTapGesture|onLongPressGesture|DragGesture|magnificationGesture' --type swift -g '!*Tests*'
rg -n '\.accessibilityIdentifier' --type swift
rg -n 'AccessibilityReduceMotion|accessibilityLabel|scrollDismissesKeyboard' --type swift -g '!*Tests*' | head -40
rg -n 'trinketSurface|trinketMaterial|trinketGlassChip|TrinketDesign' --type swift Trinket/ -g '!*Tests*' | head -40
```

Inventory dumps are for triage, not mandatory file-by-file review. Prioritize style-gate failures and controls missing dismiss / identifiers / labels.

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
- Reduce Transparency / material fallbacks: use DesignSystem surfaces (`trinketSurface` / `trinketMaterial`) — “fallback” means accessibility, not older iOS
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
./Scripts/test.sh smoke   # if identifiers or tab flows changed; toolchain permitting
```

## Commit

```
fix(ui): <imperative interaction fix>

- <what>
- check-ui-style + smoke as needed

User-Facing: yes
```
