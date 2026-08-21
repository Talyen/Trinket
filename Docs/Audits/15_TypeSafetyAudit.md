# 15. Type Safety Audit

**Goal:** Remove confirmed unsafe typing escapes and representations that permit invalid domain state in non-test, non-generated source, without replacing valid invariants with vague fallbacks.

## Intent

Remove unsafe escapes and confirmed invariant loss. Prefer one validation boundary or an impossible-state model over repeated call-site guards and fallbacks, and migrate the affected callers/decoders/tests as one bounded fix.

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
- Treat linter/compiler diagnostics as strong evidence, not the only source. Unchecked indexing, stringly typed domain identifiers, parallel optionals that admit impossible combinations, lossy casts, and erased errors are candidates when a concrete invalid state or wrong-boundary failure is shown.
- Package inits may keep hard failures; orchestration should not crash on corrupt input.
- Any `@EnvironmentObject` hit is a **must-fix**.
- Prefer `any Protocol` for existentials; `Any` mainly at serialization boundaries. Validate decoded saves via sanitizer / `init(from:)` — not runtime casts.

## Evidence bar

Unsafe escape on an orchestration path without a validated failure path; a banned observation API; or a concrete representation that admits an invalid domain state, unchecked access, lossy conversion, or erased failure that downstream code must recover from repeatedly. Prefer diagnostics and source-proven invariants over speculative syntax sweeps.
