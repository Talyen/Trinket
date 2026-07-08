# Type Safety Density Audit

Goal: Drive unsafe typing escapes toward zero in non-test, non-generated source.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

Probe force casts, force tries, force unwraps, and banned observation patterns. Fix up to **5** clear escapes; leave generated allowlists alone.

## Hard stops

- Do not hand-edit `Generated/*`.
- Do not introduce `@EnvironmentObject`, `ObservableObject`, `@StateObject`, or `@Published`.
- Prefer `@Environment(Type.self)` + `@Bindable` + `@Observable` (see `AGENTS.md`).
- Do not add net-new `swiftlint:disable` without a minimal scoped reason.

## Probes

```bash
# Existential Any as a type escape (review model/rule code; `any Protocol` is fine)
rg -n '\bAny\b' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' | head -80

# Force cast — target 0 outside tests/generated
rg -n '\bas!\b' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'

# Force try — target 0 outside tests/generated
rg -n '\btry!\b' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*'

# Force unwrap on optional chaining / IUO-ish patterns — triage carefully
rg -n '\w+!' --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' \
  | rg -v '(#!|!=|!==|\/\*|\*\/|@|#!)' | head -100

# Banned legacy observation
rg -n '@EnvironmentObject|ObservableObject|@StateObject|@Published' --type swift -g '!*Tests*'

# Lint suppressions — ratchet down
rg -n 'swiftlint:disable' --type swift -g '!*Tests*' -g '!**/Generated/*'
```

## Checks

### Force cast / try / unwrap

- `as!` → `as?` + `guard` / early return + log
- `try!` → `do/catch` with surfaced or logged error (especially save/encode paths)
- `!` unwrap → `guard let` / `??` only when a default is semantically valid

### Observation / environment

- Any `@EnvironmentObject` hit is a **must-fix** to `@Environment(Type.self)` (or equivalent)
- Do not add crash-on-missing environment objects

### `Any` and disables

- `Any` only at serialization boundaries; prefer `any Protocol` for existentials
- Validate decoded saves via sanitizer / `init(from:)` — not runtime casts
- Scope any unavoidable `swiftlint:disable` to one line with reason

## Verification

```sh
./Scripts/lint.sh
./Scripts/check-module-boundaries.sh
./Scripts/build.sh
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
