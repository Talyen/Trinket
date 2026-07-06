# Strategic Bug Hunting Audit

Goal: Find real defects using targeted, token-efficient probes — no file-by-file browsing. Prioritize by user impact + fix confidence. Ask for confirmation on any fix that changes player-visible behavior or game balance.

Point-in-time audit snapshot. Use the agent prompt below to task a coding agent with one focused bug-hunting pass. Do not treat this as standing product requirements unless explicitly cited.

## Agent prompt

Copy everything between the markers into a new agent session:

```text
--- BEGIN BUG HUNTING TASK ---

You are working on Trinket, a portrait-first iOS fantasy idle auto-battler (Swift 6 / SwiftUI, iOS 26). Read `AGENTS.md` and `Docs/Architecture.md` before editing.

**Mission:** Find and fix real bugs by running six targeted search probes (below). Each probe produces a short list of candidate files. Triage by severity × fix confidence, propose fixes, and ask the user to confirm any player-facing behavior change.

**Hard stops**
- Do not read every file — run the probes, triage the output, pick the best 3–5 bugs.
- Do not refactor, rename, restyle, or simplify unless fixing a confirmed bug.
- Do not touch `Docs/Roadmap.md` speculative features, `ContentManifest/` (unless a generated catalog reference is stale), `Assets.xcassets`, `Resources/Music`, `.DerivedData/`, or `Generated/*` (edit manifests and regenerate).
- Do not delete or alter `accessibilityIdentifier` values used in `TrinketUITests` unless the control itself is removed.
- Do not weaken `BattleStateTestFactory.makeBattle(..., rngSeed: 0)` determinism.

**Before fixing any bug, ask the user:**
For any fix that changes player-visible behavior (game balance, UI layout/text, flow, timing, error messages):
1. State the observed bug and its severity.
2. Describe the proposed fix.
3. Ask the user to confirm before implementing.
4. If there are multiple reasonable approaches, list them with a recommendation.

**Workflow**

1. **Probe** — Run each probe below. Collect output, deduplicate, classify by bug type.
2. **Triage** — Score each finding (P0 crashes/data-loss → P5 cosmetic). Rank by user impact × fix confidence.
3. **Select** — Pick the 3–5 highest-value bugs. One may be a fix-everywhere pattern (e.g., missing weak self in 3 places).
4. **Plan** — For each, write a one-paragraph fix plan. Note which files change and any new test needed.
5. **Fix** — Apply the smallest correct diff. Do not fix things you didn't set out to fix.
6. **Verify** — Run the matching test tier (see § Verification).
7. **Report** — Summarize: what was found (not just fixed), severity breakdown, any declined-by-user items, and recommended follow-up probes.

---

## Probe 1: Retain Cycle & Lifetime Mismatch

Signals: missing `[weak self]`, `Task` in `@MainActor` class without lifetime management, stale delegate, timer without invalidation.

```bash
# Missing weak self in closures assigned to stored properties
rg -n '\.on\w+\s*=\s*\{' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'

# Task in @MainActor class — check that the Task is stored + cancelled
rg -n 'Task\s*\{' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'

# Timer / display-link patterns
rg -n 'Timer\b|CADisplayLink|DisplayLink' --type swift -g '!*Tests*' -g '!*UITests*'

# Delegates without weak
rg -n '(var|let)\s+\w+Delegate\??\s*:\s*\w+\s*[={]' --type swift -g '!*Tests*' -g '!*UITests*'
```

For each hit: is the closure's captured `self` released when the owning object deinits? Is the Task cancelled in `deinit`? Are there stored closures that could outlive their owner?

Key target: `MusicPlayer.swift` — `fadeTask` overwrites without atomic cancel, and `Task { @MainActor in` captures `self` implicitly. Verify `deinit` cancels `fadeTask`.

---

## Probe 2: Concurrency Safety Gaps

Signals: `@unchecked Sendable` in non-generated code, data races across `@MainActor`-isolated state, non-`Sendable` types passed across actor boundaries.

```bash
# @unchecked Sendable — each is a concurrency blind spot
rg -n '@unchecked Sendable' --type swift -g '!*Tests*' -g '!*UITests*'

# Class with mutable stored properties not isolated to MainActor
rg -n '^final class|^class\s' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' \
  | rg -v '@MainActor'

# Non-@MainActor class with mutable state read from Task closures
# (Manual: cross-reference Probe 1 Task results with class declarations)

# Generated struct with @unchecked Sendable — check it has only value-type members
rg -n '@unchecked Sendable' --type swift
```

For each `@unchecked Sendable`: can it be removed (prove safety via types)? If the type has reference-type members or mutable state, document why suppression is needed.

Key targets: `AbilityComparisonRowCollector`, `MatchupRowCollector` in `BattleBalanceTools`, and `CombatantArtReference` in generated code.

---

## Probe 3: Post-Refactoring Orphans

Signals: properties/functions in collapsed layers that are now unused, delegate protocols with only partial implementation, stale enum cases, dead error types.

The recent complexity audit collapsed many pass-through layers (see git log). Find likely orphans:

```bash
# Properties that are set but may no longer be read (orphaned state)
# Manual check: grep for each write-site, confirm there's a read-site outside tests
rg -n 'self\.\w+\s*=' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' \
  | rg -v '(isActive|isHidden|alpha|frame|\.text|\.volume|\.numberOfLoops|\.currentTime|\.delegate|accessibility|\.isAnimating|\.scale|\.opacity|\.offset|\.rotation|\.color|\.font)' \
  | head -50

# Error types where cases are never thrown
rg -n 'enum\s+\w+Error' --type swift -g '!*Tests*' -g '!*UITests*' -A10 \
  | rg 'case\s+\w+'

# Functions that only delegate to another object (pass-through remnant)
rg -n 'func\s+\w+' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' -A3 \
  | rg -B1 'return\s+\w+\.\w+\(' | head -20
```

For each suspect: use `rg '\bPropertyName\b'` to check for references. If a property is set but never read (outside tests), it's orphaned state. If an error case is never thrown, it's dead code.

Key targets: `BattleSession.swift`, `AppState.swift`, `ActiveBattleConfiguration.swift` — the most-churned files in the refactoring wave.

---

## Probe 4: Test Gap × Churn

Signals: files modified 15+ times with no matching unit test (only UI tests or nothing).

Manual check — for each high-churn file below, count modifications and check for a unit test companion:

```bash
for f in \
  Trinket/Features/Battle/BattleView.swift \
  Trinket/Features/Play/PlayView.swift \
  Trinket/App/ContentView.swift \
  Trinket/State/AppState.swift \
  Trinket/State/BattleSession.swift \
  Trinket/Shared/Detail/CombatantDetailPane.swift; do
  echo "$f: $(git log --oneline --diff-filter=M -- "$f" | wc -l) modifications"
  test_file="${f/Trinket\//TrinketTests/}"
  test_file="${test_file%.swift}Tests.swift"
  if [ -f "$test_file" ]; then
    echo "  → Unit test found: $test_file"
  else
    echo "  → NO unit test companion"
  fi
done
```

For each gap: could a focused unit test catch a class of bug that UI tests cannot (state machine transitions, persistence calls, delegate callbacks)? If yes, write one test that exercises the bug-vulnerable path. Do not write tests that only assert trivial existence.

BattleView in particular: verify that `BattleFlowUITests` adequately covers mid-battle state transitions, pause/background, and victory/defeat flows.

---

## Probe 5: API Misuse & Silent Failure

Signals: `try?` on operations that should surface errors, async calls without cancellation handling, `willSet`/`didSet` with side effects, NotificationCenter observers not removed.

```bash
# try? on non-optional-returning calls (likely swallowing errors)
rg -n 'try\?\s+\w+' --type swift -g '!*Tests*' -g '!*UITests*' \
  | rg -v '(Task\.sleep|decode|encode|audioSession|setActive|setCategory|from:)'

# didSet/willSet with side effects (fragile, easy to introduce bugs)
rg -n '(didSet|willSet)\s*\{' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' -B1 -A5

# NotificationCenter observers — verify removal
rg -n 'NotificationCenter|addObserver|\.publisher\(for:' --type swift -g '!*Tests*' -g '!*UITests*' -B1

# SwiftUI .task{} — verify cancellation is handled (no long-lived work without periodic cancellation check)
rg -n '\.task\s*\{' --type swift -g '!*Tests*' -g '!*UITests*' -A10
```

For `try?` hits: should this be `do/catch` with logging? Every `try?` in orchestration code (state transitions, battle outcome, save) that could fail silently is a P1 or P2.

For `didSet`/`willSet`: side-effecting property observers are fragile — did a recent refactor add a write to a property that triggers an unexpected observer cascade?

For `.task {}`: SwiftUI tasks are automatically cancelled when the view disappears — but if the task spawns subtasks that outlive the parent, those may leak.

---

## Probe 6: Edge Case / Boundary Violations

Signals: collection bounds, empty state handling, integer overflow, stage transitions, reward grants.

```bash
# Array/index access without bounds check — potential crash on empty collection
rg -n '\[(\w+)\s*\+\s*1\]|\[(\w+)\s*-\s*1\]' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'

# Force unwrap on optional collection element
rg -n '\.first\s*!' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'

# .prefix() / .suffix() without bounds awareness
rg -n '\.prefix\(|\.suffix\(' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'

# Stage/reward logic — double-grant risk (from BehaviorHardeningAudit)
rg -n 'grant|reward|completeStage|claim' --type swift -g '!*Tests*' -g '!*UITests*' -B2 -A2
```

Index access with `±1` is the classic off-by-one: is `array[index + 1]` guarded by `index < array.count - 1`? Are `.first!` results from collections that could genuinely be empty?

---

## Bug Severity Classification

| Severity | Label | Criteria |
|----------|-------|----------|
| P0 | Crash/Data Loss | Force-unwrap on empty, assertion failure reachable by user, double-reward grant, save corruption |
| P1 | Wrong Behavior | Wrong battle outcome, wrong reward amount, stuck progress, wrong UI state after transition |
| P2 | Degraded UX | Missing feedback, frozen UI during save, animation glitch, wrong copy |
| P3 | Silent Failure | `try?` swallowing an error that should be logged, retried, or surfaced |
| P4 | Maintainability | Dead code, orphaned state, unused delegate, stale comment |
| P5 | Future Risk | `@unchecked Sendable` without documented reason, missing `weak`, non-cancelled Task |

## Verification

| Change | Minimum to run |
|--------|----------------|
| `Packages/BattleEngine/` rules or effect handlers | `./Scripts/test-package.sh BattleEngine` |
| `TrinketPersistence/` stores or save model | `./Scripts/test-package.sh TrinketPersistence` |
| `Trinket/State/`, `BattleShell/`, app orchestration | `./Scripts/test.sh unit <FocusedClass>` |
| SwiftUI layout / identifiers | `./Scripts/test.sh smoke` |
| Cross-cutting (app + package) | `./Scripts/test.sh unit` then `./Scripts/test.sh smoke` |

Always run:
```sh
./Scripts/check-module-boundaries.sh
./Scripts/lint.sh
```

If you changed generated-adjacent code or altered manifests: `./Scripts/generate.sh` and commit regenerated output.

## Report format

After all fixes (or after triaging with the user), write a summary:

```markdown
## Bug Hunt Results

| # | Probe | File | Bug | Severity | Fixed? |
|---|-------|------|-----|----------|--------|
| 1 | Retain | MusicPlayer.swift | Task captures self; deinit doesn't cancel fadeTask | P4 | Yes |
| 2 | Concurrency | MatchupRowCollector | @unchecked Sendable — documented as acceptable | P5 | User declined |

**Not fixed (user declined):** Item 2 — low risk, balance tooling only.
**Follow-up recommended:** Re-run Retain Cycle probe after next feature work.
```

--- END BUG HUNTING TASK ---
```

## Targets

Each probe maps to a shell command or short manual check. Run all 6; expect under 10 minutes of search output. Triage only the findings with real user impact.

| # | Probe | Command | Expected output size | Typical yield |
|---|-------|---------|---------------------|---------------|
| 1 | Retain Cycle | `rg` for stored closures, Tasks, timers, delegates | 10–30 lines | 1–3 real risks |
| 2 | Concurrency Safety | `rg` for `@unchecked Sendable`, non-MainActor classes | 5–15 lines | 1–2 confirms |
| 3 | Orphans | `rg` for set-but-not-read, pass-through, dead enum cases | 20–50 lines | 2–4 dead paths |
| 4 | Test Gap × Churn | `git log` counts + cross-reference test dir | 5–10 files | 1–2 untested paths |
| 5 | API Misuse | `rg` for `try?` swallows, didSet, notifications | 10–30 lines | 1–2 silent failures |
| 6 | Edge Cases | `rg` for ±1 index, `.first!`, reward grants | 10–20 lines | 0–2 bugs |

## Probes

Each probe's search commands and manual review steps are documented in the agent prompt above. The agent runs all six, then triages.

## Workflow

1. Run all 6 probes (parallel where possible).
2. Triage findings by severity (P0–P5).
3. Select 3–5 fixes with the best impact/confidence ratio.
4. For each fix requiring a player-facing change, ask the user with a clear description and recommendation.
5. Fix, verify, and report.

## Confirmation protocol

Before implementing a bug fix that changes player-visible behavior:

| Do | Don't |
|----|-------|
| State the bug clearly (what happens vs what should) | Don't say "I'll fix this" and implement without waiting |
| Name the file/line | Don't ask about trivial non-functional changes |
| Describe the proposed change | Don't propose two unrelated fixes in one question |
| Recommend one approach if there are several | Don't over-explain Swift mechanics |
| Note the severity | Don't ask about things the agent should decide (file structure, var names) |

Example:

> **Found:** `BattleSession.swift:142` — `grantRewards()` can be called twice if the user taps "Continue" before the first async save completes, granting double rewards.
> **Fix:** Add `isGrantingRewards` flag, set true on entry, reset on completion. Any concurrent call returns early.
> **Severity:** P1 (wrong behavior, rewards duplicated).
> **Confirm?** No player-facing design decision — purely internal guard. Proceeding.

If the fix changes some intrinsic behavior:

> **Found:** Player can start a battle with 0 equipped abilities (because the "Ready" button isn't disabled when the loadout is empty).
> **Fix:** Disable the Ready button when `equippedAbilities.isEmpty`.
> **Alternative:** Show a warning toast instead and let them proceed.
> **Recommendation:** Disable the button — matches genre convention, prevents confused players from entering battle ill-equipped.
> **Confirm?**

## Verification

See the agent prompt's verification table. At minimum:
- `./Scripts/lint.sh` and `./Scripts/check-module-boundaries.sh` must pass.
- Changed tests must pass (targeted test, or full unit if cross-cutting).
- Smoke UI tests if identifiers or flow changed.

## Participant questions

When encountering a potential bug with ambiguous intent, ask the user:

1. **Design intent:** "The code does X, but based on the product description it should do Y. Is Y the intended behavior?"
2. **Edge case policy:** "What should happen when the player does Z — crash? show an error? silently ignore?"
3. **Balance impact:** "This changes the reward for stage N from 100 gold to the intended 50 gold. Confirm?"
