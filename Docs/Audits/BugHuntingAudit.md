# Strategic Bug Hunting Audit

Goal: Find and fix real defects with targeted probes — no file-by-file browsing.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append hunt results to this file.

Concurrency → [SwiftConcurrencyDataRaceAudit.md](SwiftConcurrencyDataRaceAudit.md).  
Dead code → [DeadCodeRatioAudit.md](DeadCodeRatioAudit.md).  
Persistence hardening → [BehaviorHardeningAudit.md](BehaviorHardeningAudit.md).

## Mission

Run targeted probes, confirm candidate defects, and fix up to three highest-value bugs. A pass with no confirmed defect is successful. Summarize evidence and any intentional non-fixes in the commit/PR body.

Read `AGENTS.md` and `Docs/Platform/Architecture.md` before editing.

Do **not** re-run sibling audits’ full suites — only chase hits from these probes. Defer P4/P5 to the owning audit by default.

## Hard stops

- Do not read every file — probe, triage, fix.
- Do not refactor/rename/restyle unless required to fix a confirmed bug.
- Do not expand into speculative backlog the user did not cite; do not touch manifests (unless a stale catalog ref), assets, music, `.DerivedData/`, or hand-edit `Generated/*`.
- Do not alter `accessibilityIdentifier` values unless removing the control.
- Do not weaken `BattleStateTestFactory.makeBattle(..., rngSeed: 0)`.

## Confirmation policy (autonomous-friendly)

- **Auto-fix** P0–P2 correctness bugs (crashes, data loss, double grants, stuck state, clear wrong behavior).
- **Skip and note in the PR/commit body** for balance retunes, player-facing copy/layout design choices, or ambiguous product intent — do not block the audit waiting for answers.
- Never ask about naming, file structure, or obvious internal guards.

## Workflow

1. Probe a bounded area
2. Confirm the candidate with a reproducer, failing test, state-transition trace, or direct ownership proof
3. Select up to three P0–P2 fixes (a trivial P3 is optional)
4. Apply smallest correct diffs
5. Verify (§ Verification)
6. Commit + report in commit body

## Probes

### 1. Retain cycle & lifetime

```bash
rg -n '\.on\w+\s*=\s*\{' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' .
rg -n 'Task\s*\{' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' .
rg -n 'Timer\b|CADisplayLink|ContinuousClock|SuspendingClock|Task\.sleep' --type swift -g '!*Tests*' -g '!*UITests*' .
rg -n '(var|let)\s+\w+Delegate\??\s*:\s*\w+' --type swift -g '!*Tests*' -g '!*UITests*' .
```

Check: stored closures release with owner; Tasks cancelled; delegates `weak`.

### 2. API misuse & silent failure

```bash
rg -n 'try\?\s+' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' . \
  | rg -v '(Task\.sleep|decode|encode|audioSession|setActive|setCategory|from:)'
rg -n '(didSet|willSet)\s*\{' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' -B1 -A5 .
rg -n 'NotificationCenter|addObserver|\.publisher\(for:' --type swift -g '!*Tests*' -g '!*UITests*' .
rg -n '\.task\s*\{' --type swift -g '!*Tests*' -g '!*UITests*' -A8 .
```

Suspect silent `try?` on save / battle outcome / state transitions. `.task` subtasks must not outlive cancellation.

### 3. Edge cases / bounds

```bash
rg -n '\[(\w+)\s*\+\s*1\]|\[(\w+)\s*-\s*1\]' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' .
rg -n '\.first!' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' .
rg -n 'grant|reward|completeStage|claim' --type swift -g '!*Tests*' -g '!*UITests*' -B2 -A2 .
```

### 4. Regression coverage

Add a focused regression only when it distinguishes the defect from existing coverage and will catch its recurrence. SwiftUI rendering belongs in smoke/UI coverage, not existence-only unit companions.

## Severity

| Sev | Criteria | Default disposition |
|-----|----------|---------------------|
| P0 | Crash / data loss / double reward / save corruption | Fix now |
| P1 | Wrong battle/progress/UI state | Fix now |
| P2 | Degraded UX (stuck spinner, missing dismiss) | Fix when confirmed and scoped |
| P3 | Confirmed recoverable failure without appropriate diagnostics or surfaced state | Fix only if trivial |
| P4 | Maintainability (orphaned state) | Defer to [DeadCodeRatioAudit.md](DeadCodeRatioAudit.md) |
| P5 | Future concurrency risk | Defer to [SwiftConcurrencyDataRaceAudit.md](SwiftConcurrencyDataRaceAudit.md) |

## Verification

| Change | Minimum |
|--------|---------|
| BattleEngine | `./Scripts/test-package.sh BattleEngine` |
| Persistence | `./Scripts/test-package.sh TrinketPersistence` |
| App state / shell | `./Scripts/test.sh unit <FocusedClass>` |
| Identifiers / flow | `./Scripts/test.sh smoke` |

Always: `./Scripts/check-module-boundaries.sh` and `./Scripts/lint.sh`. Skip build/test when the toolchain is absent; note skips in the commit body.

## Commit / report

```
fix(<scope>): <imperative bug fix>

- Probe: <n> — <one-line bug>
- <verification>

User-Facing: yes | no
```

Commit body table (do not write into this file):

```markdown
| # | Probe | File | Bug | Sev | Fixed? |
|---|-------|------|-----|-----|--------|
```
