---
type: execution-plan
status: active
created: 2026-10-15
updated: 2026-10-15
expires: 2026-10-29
---

# Localization release validation

## Objective

Finish localized talent-reward coverage, inspect compact-phone layouts at normal
and largest native text sizes, fix reproduced defects, and verify CI/release packaging.
Artwork lettering is explicitly excluded by the user.

## Work

- [x] Isolate from local main aad14f6c0; inspect verification and simulator contracts.
- [x] Extend existing localization journey with real earned talent choices and return.
- [x] Run focused XCTest diagnostics on managed iPhone SE; retain/review screenshots.
- [x] Run normal German/French and largest native text configurations for all five languages.
- [x] Fix confirmed layout/interaction failures and recheck them.
- [ ] Verify generated consistency and Release archive language bundles/offline resources.
- [ ] Complete required handoff, review/commit/integrate and exact-commit hosted CI.

## Boundaries

No artwork edits or release publication. Hosted CI currently references older remote
commits; a push decision must use the concrete reviewed task commit. No simulator
or package full suites on the laptop merely to substitute for hosted coverage.
Use bounded localization XCTest selectors for the known missing interaction and layout evidence.

## Findings

- German/French normal-text SE journeys passed (2 tests); screenshots retained outside the worktree.
- Largest native text reproduced the selected-talent inspector overflowing the viewport and hiding Unlock. Bound the details to a scrollable panel and retain a separate action; all five language journeys passed.
- Correct the screenshot helper main-actor capture and use the unique talent button when checking capture readiness.
- SwiftPM stalled in exited Git subprocesses; command-scoped `core.fsmonitor=false` avoids the stall without changing repository settings.
- Campaign's active encounter footer now reflows instead of widening the screen. All five largest-text journeys passed the horizontal guard.
- Give the scrollable inspector the selected node identity so a new node starts at the beginning of its rule.
- Screenshot review caught an untranslated Approach action. Strict computed-action extraction now inventories nine entries; a separate GPT-6.1-Sol High review approved all 45 translations. Localization checks and 20 Python regressions pass; previous translations/reviews are unchanged and compact formatting is retained.
- The French Full Game screenshot exposed a truncated price despite the purchase button being hittable. Move support controls into scrollable content and preserve the complete purchase label. French/German largest-text journeys passed; screenshots show both complete prices and the translated Approach action.
- XCTest's scroll view frame extends behind the pinned purchase action, and its hittability can also include covered content. Bound gestures above that action and require Restore's rendered frame to fit there. The strengthened French largest-text journey passed and its support screenshot shows Restore, Privacy, Family Sharing, and the full price.
- The simulator build passes compiler extraction coverage and all six compiled language checks. The unsigned device archive remains a separate verification step.
- Final-source normal French and double-length English journeys passed. Real-language captions fit; Apple's synthetic double-English mode still crowds the native tab captions and leaves a format fragment in one doubled talent rule. These synthetic-only limits are retained in screenshots rather than hidden by disabling pseudolocalization or altering shipping wording.
- Retain evidence under `/tmp/trinket-localization-release-validation/` before worktree cleanup. Native text size uses a restoring context; hardware purchase authorization is outside these display checks.
