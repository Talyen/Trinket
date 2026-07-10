# UI Interaction & Accessibility Audit

Goal: Find confirmed interaction, feedback, and accessibility defects that static types do not catch.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

UI **test** speed/tier issues → [E2ETestQualityAudit.md](E2ETestQualityAudit.md). Layout, typography, and DesignSystem adoption → [AppleNativeUIAudit.md](AppleNativeUIAudit.md).

## Mission

1. Select one affected flow and run the relevant probes
2. Confirm a navigation, feedback, or accessibility defect by exercising the flow or using focused UI-test evidence
3. Make a bounded set of clear fixes; a clean pass is valid
4. Verify the affected flow and its matching smoke/UI test
5. Commit

## Hard stops

- Do not restyle unrelated chrome.
- Do not change `accessibilityIdentifier` strings unless removing the control.
- Do not expand into layout, typography, or DesignSystem migrations; [AppleNativeUIAudit.md](AppleNativeUIAudit.md) owns those.
- iPhone portrait-first; skip iPad-only hover work unless product scope expands.
- Do not expand into UI test rewrites (E2E audit owns those).
- Do not expand a selected-flow check into a full-tab manual pass; skip unavailable Simulator/device checks without failing the audit.

## Probes

```bash
rg -n 'sheet|popover|fullScreenCover|alert|confirmationDialog|menu|contextMenu' --type swift -g '!*Tests*' .
rg -n 'onTapGesture|onLongPressGesture|DragGesture|magnificationGesture' --type swift -g '!*Tests*' .
rg -n '\.accessibilityIdentifier' --type swift .
rg -n 'AccessibilityReduceMotion|accessibilityLabel|scrollDismissesKeyboard' --type swift -g '!*Tests*' . | head -40
```

Inventory dumps are for triage, not mandatory file-by-file review. Prioritize a confirmed missing dismiss, stuck state, inaccessible control, or gesture conflict.

Manual (when Simulator available): exercise only the selected flow, including its entry and exit path.

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
- Long `Task` work shows progress; victory/defeat screens always dismissible

### Accessibility

- Controls expose an accessible name through their visible label or explicit accessibility label; use identifiers only when UI-test targeting needs a stable semantic control ID
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
- Keyboard dismissal on text fields where applicable: `.scrollDismissesKeyboard(.immediately)` or equivalent
- Empty states for empty collection/inventory/homestead

## Verification

```sh
./Scripts/lint.sh
./Scripts/test.sh smoke   # if identifiers or tab flows changed; toolchain permitting
```

## Commit

```
fix(ui): <imperative interaction fix>

- <what>
- focused flow verification + smoke as needed

User-Facing: yes
```
