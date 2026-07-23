# Unsafe Escape Audit

**Goal:** Remove confirmed unsafe typing escapes in non-test, non-generated source without replacing valid invariants with vague fallbacks.

## Intent

Find unsafe escapes via compiler/linter output and targeted probes. Prefer one validation boundary or an impossible-state model over repeated call-site guards and fallbacks. Write a plan to fix all identified unsafe typing escapes (breaking into phases if the scope is large); a clean pass is valid, and significant typing seams remain proposals.

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

- **Force Casts & Force Tries:** Search for `as!` or `try!` in production source (`Trinket/` and `Packages/*/Sources`); verify fail-safe fallback or validation boundaries exist.
- **Implicit Optional String Interpolation:** Search for `"\(.*?\?"` or `"\(.*?\!)"` in UI label text; ensure optionals are safely unwrapped to prevent `"Optional(...)"` display bugs in UI.
- **Unsafe Numerical Type Conversions:** Search for `Int(doubleVal)`, `UInt(intVal)`, or `Int32(...)` without range checking or safe boundary clipping that can trap at runtime on overflow/negative inputs.
- **Raw Enum Decoding Traps:** Search for `MyEnum(rawValue: str)!` or `init?(rawValue:)` unwraps in state decoding; ensure default cases or fallback enums handle corrupt/outdated persistence strings.
- **Banned Legacy Observation APIs:** Run `./Scripts/check-platform-api-bans.sh` and search for `@EnvironmentObject`, `@StateObject`, or `@Published`.
- **Fatal Error & Precondition Audit:** Search for `fatalError` or `preconditionFailure` in app orchestration layers (`Trinket/State`, `Trinket/Features`).
