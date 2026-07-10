# Unsafe Escape Audit

**Goal:** Remove confirmed unsafe typing escapes in non-test, non-generated source without replacing valid invariants with vague fallbacks.

**Siblings:** silent save / orchestration `try?` → [BehaviorHardeningAudit.md](BehaviorHardeningAudit.md); concurrency bypasses → [SwiftConcurrencyDataRaceAudit.md](SwiftConcurrencyDataRaceAudit.md).

## Intent

Find unsafe escapes via compiler/linter output and targeted probes. Fix a bounded set of confirmed issues; a clean pass is valid.

## Hard stops

- Do not introduce `@EnvironmentObject`, `ObservableObject`, `@StateObject`, or `@Published` — prefer `@Environment(Type.self)` + `@Bindable` + `@Observable`.
- Do not add net-new `swiftlint:disable` without a minimal scoped reason.
- Do not chase every `\bAny\b` or every `!` — triage from probes and diagnostics.

## Triage

| Priority | Examples |
|----------|----------|
| P0 | `try!` / `as!` on save, sync, or battle outcome paths; banned observation APIs |
| P1 | Force unwrap that can trap on empty/corrupt data |
| P2 | `fatalError` in recoverable orchestration |
| P3 | Style-only `Any` / disable churn — skip unless trivial |

## Domain rules

- `as!`, `try!`, and force unwraps need an input-appropriate validation or failure path; do not introduce a default unless it is semantically valid.
- Treat linter/compiler diagnostics as primary evidence; grep hits are review candidates.
- Package inits may keep hard failures; orchestration should not crash on corrupt input.
- Any `@EnvironmentObject` hit is a **must-fix**.
- Prefer `any Protocol` for existentials; `Any` mainly at serialization boundaries. Validate decoded saves via sanitizer / `init(from:)` — not runtime casts.

## Probe hints

`as!`, `try!`, force-unwrap candidates, `fatalError` / `preconditionFailure`, banned observation APIs, `swiftlint:disable`, existential `Any` in models/persistence.

## Verify

`lint.sh` + boundaries + `build.sh` (toolchain permitting); `test-package.sh TrinketPersistence` if persistence typing changed.
