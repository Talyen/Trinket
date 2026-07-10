# Unsafe Escape Audit

Goal: Remove confirmed unsafe typing escapes in non-test, non-generated source without replacing valid invariants with vague fallbacks.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

Silent save / orchestration `try?` → [BehaviorHardeningAudit.md](BehaviorHardeningAudit.md).  
Concurrency bypasses → [SwiftConcurrencyDataRaceAudit.md](SwiftConcurrencyDataRaceAudit.md).

## Mission

Use compiler/linter output and targeted probes to find unsafe escapes. Fix a bounded set of confirmed issues; a clean pass is valid.

## Hard stops

- Do not hand-edit `Generated/*`.
- Do not introduce `@EnvironmentObject`, `ObservableObject`, `@StateObject`, or `@Published`.
- Prefer `@Environment(Type.self)` + `@Bindable` + `@Observable` (see `AGENTS.md`).
- Do not add net-new `swiftlint:disable` without a minimal scoped reason.
- Do not chase every `\bAny\b` or every `!` in the repo — use the probes below and triage.

## Probes

```bash
# Always pass an explicit path (`.`) — pathless rg hangs in Cursor cloud shells (readable stdin socket).

# Force cast — target near-0 outside tests/generated
rg -n '\bas!\b' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' .

# Force try — target near-0 outside tests/generated (save/encode paths are P0)
rg -n '\btry!\b' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' .

# Force-unwrap candidates (inspect context; this intentionally excludes prefix !)
rg -n '\b[A-Za-z_][A-Za-z0-9_]*!\s*(\.|\[|\)|,|$)|\]!\s*' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' . | head -80
rg -n '\bfatalError\b|\bpreconditionFailure\b' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' .

# Banned legacy observation — must-fix
rg -n '@EnvironmentObject|ObservableObject|@StateObject|@Published' --type swift -g '!*Tests*' .

# Lint suppressions — ratchet down
rg -n 'swiftlint:disable' --type swift -g '!*Tests*' -g '!**/Generated/*' .

# Secondary (optional): existential Any in models/persistence only — not a primary gate
rg -n '\bAny\b' --type swift \
  Packages/TrinketPersistence/Sources Packages/TrinketCore/Sources \
  -g '!*Tests*' -g '!**/Generated/*' | head -40
```

## Checks

### Force cast / try / unwrap

- `as!`, `try!`, and force unwraps need an input-appropriate validation or failure path; do not introduce a default unless it is semantically valid
- Treat linter/compiler diagnostics as primary evidence; grep hits are review candidates
- Triage `fatalError` / `preconditionFailure`: package inits may keep hard failures; orchestration should not crash on corrupt input

### Observation / environment

- Any `@EnvironmentObject` hit is a **must-fix** to `@Environment(Type.self)` (or equivalent)
- Do not add crash-on-missing environment objects

### `Any` and disables

- Prefer `any Protocol` for existentials; `Any` mainly at serialization boundaries
- Validate decoded saves via sanitizer / `init(from:)` — not runtime casts
- Scope any unavoidable `swiftlint:disable` to one line with reason

## Triage

| Priority | Examples |
|----------|----------|
| P0 | `try!` / `as!` on save, sync, or battle outcome paths; banned observation APIs |
| P1 | Force unwrap that can trap on empty/corrupt data |
| P2 | `fatalError` in recoverable orchestration |
| P3 | Style-only `Any` / disable churn — skip unless trivial |

## Verification

```sh
./Scripts/lint.sh
./Scripts/check-module-boundaries.sh
./Scripts/build.sh   # toolchain permitting
# If persistence typing changed:
./Scripts/test-package.sh TrinketPersistence
```

## Commit

```
fix(<scope>): remove <unsafe escape>

- Replace <as!/try!/!> with safe control flow
- <verification>

User-Facing: no
```
