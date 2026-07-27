# Unsafe Escape Audit

**Goal:** Remove confirmed unsafe typing escapes in non-test, non-generated source without replacing valid invariants with vague fallbacks.

## Intent

Remove unsafe escapes. Prefer one validation boundary or an impossible-state model over repeated call-site guards and fallbacks. A clean pass is valid; significant typing seams remain proposals per [README.md](README.md).

## Hard stops

- Do not introduce `@EnvironmentObject`, `ObservableObject`, `@StateObject`, or `@Published` — prefer `@Environment(Type.self)` + `@Bindable` + `@Observable`.
- Do not add net-new `swiftlint:disable` without a minimal scoped reason.
- Do not chase every `\bAny\b` or every `!` — triage from diagnostics and confirmed risk.

## Triage

| Priority | Examples |
|----------|----------|
| P0 | `try!` / `as!` on save, sync, or battle outcome paths; banned observation APIs |
| P1 | Force unwrap that can trap on empty/corrupt data |
| P2 | `fatalError` in recoverable orchestration |
| P3 | Style-only `Any` / disable churn — skip unless trivial |

## Domain rules

- `as!`, `try!`, and force unwraps need an input-appropriate validation or failure path; do not introduce a default unless it is semantically valid.
- Treat linter/compiler diagnostics as primary evidence; other hits are review candidates.
- Package inits may keep hard failures; orchestration should not crash on corrupt input.
- Any `@EnvironmentObject` hit is a **must-fix**.
- Prefer `any Protocol` for existentials; `Any` mainly at serialization boundaries. Validate decoded saves via sanitizer / `init(from:)` — not runtime casts.

## Evidence bar

Unsafe escape on an orchestration path without a validated failure path, or a banned observation API. Prefer diagnostics over speculative sweeps.
