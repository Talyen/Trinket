# Strategic Bug Hunting Audit

Goal: Find and fix real defects with targeted probes — no file-by-file browsing.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append hunt results to this file.

Concurrency → [SwiftConcurrencyDataRaceAudit.md](SwiftConcurrencyDataRaceAudit.md).  
Dead code → [DeadCodeRatioAudit.md](DeadCodeRatioAudit.md).  
Persistence hardening → [BehaviorHardeningAudit.md](BehaviorHardeningAudit.md).

## Mission

Run the probes below, triage by severity × fix confidence, fix **3–5** highest-value bugs, verify, commit. Summarize in the commit/PR body.

Read `AGENTS.md` and `Docs/Architecture.md` before editing.

## Hard stops

- Do not read every file — probe, triage, fix.
- Do not refactor/rename/restyle unless required to fix a confirmed bug.
- Do not touch Roadmap speculative features, manifests (unless a stale catalog ref), assets, music, `.DerivedData/`, or hand-edit `Generated/*`.
- Do not alter `accessibilityIdentifier` values unless removing the control.
- Do not weaken `BattleStateTestFactory.makeBattle(..., rngSeed: 0)`.

## Confirmation policy (autonomous-friendly)

- **Auto-fix** P0–P2 correctness bugs (crashes, data loss, double grants, stuck state, clear wrong behavior).
- **Stop and ask** only for balance retunes, player-facing copy/layout design choices, or ambiguous product intent.
- Never ask about naming, file structure, or obvious internal guards.

## Workflow

1. Probe (parallel where possible)
2. Triage P0–P5
3. Select 3–5 fixes
4. Apply smallest correct diffs
5. Verify (§ Verification)
6. Commit + report in commit body

## Probes

### 1. Retain cycle & lifetime

```bash
rg -n '\.on\w+\s*=\s*\{' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'
rg -n 'Task\s*\{' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'
rg -n 'Timer\b|CADisplayLink|ContinuousClock|SuspendingClock|Task\.sleep' --type swift -g '!*Tests*' -g '!*UITests*'
rg -n '(var|let)\s+\w+Delegate\??\s*:\s*\w+' --type swift -g '!*Tests*' -g '!*UITests*'
```

Check: stored closures release with owner; Tasks cancelled; delegates `weak`.

### 2. API misuse & silent failure

```bash
rg -n 'try\?\s+' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' \
  | rg -v '(Task\.sleep|decode|encode|audioSession|setActive|setCategory|from:)'
rg -n '(didSet|willSet)\s*\{' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' -B1 -A5
rg -n 'NotificationCenter|addObserver|\.publisher\(for:' --type swift -g '!*Tests*' -g '!*UITests*'
rg -n '\.task\s*\{' --type swift -g '!*Tests*' -g '!*UITests*' -A8
```

Suspect silent `try?` on save / battle outcome / state transitions. `.task` subtasks must not outlive cancellation.

### 3. Edge cases / bounds

```bash
rg -n '\[(\w+)\s*\+\s*1\]|\[(\w+)\s*-\s*1\]' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'
rg -n '\.first!' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'
rg -n 'grant|reward|completeStage|claim' --type swift -g '!*Tests*' -g '!*UITests*' -B2 -A2
```

### 4. Test gap × churn (optional, max one fix)

```bash
for f in \
  Trinket/State/AppState.swift \
  Trinket/State/BattleSession.swift \
  Trinket/BattleShell/ActiveBattleConfiguration.swift; do
  echo "$f: $(git log --oneline --diff-filter=M -- "$f" | wc -l) mods"
done
```

Only add a unit test when it would catch a real bug class UI tests miss. Do not add existence-only tests. SwiftUI views are covered by smoke/UI, not unit companions.

## Severity

| Sev | Criteria |
|-----|----------|
| P0 | Crash / data loss / double reward / save corruption |
| P1 | Wrong battle/progress/UI state |
| P2 | Degraded UX (stuck spinner, missing dismiss) |
| P3 | Silent failure that should log |
| P4 | Maintainability (orphaned state) — prefer DeadCode audit |
| P5 | Future risk — prefer Concurrency audit |

## Verification

| Change | Minimum |
|--------|---------|
| BattleEngine | `./Scripts/test-package.sh BattleEngine` |
| Persistence | `./Scripts/test-package.sh TrinketPersistence` |
| App state / shell | `./Scripts/test.sh unit <FocusedClass>` |
| Identifiers / flow | `./Scripts/test.sh smoke` |

Always: `./Scripts/check-module-boundaries.sh` and `./Scripts/lint.sh`.

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
