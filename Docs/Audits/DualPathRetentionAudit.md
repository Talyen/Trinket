# Dual-Path & Compatibility Retention Audit

**Goal:** Delete confirmed parallel live implementations, migration shims past their window, and “keep both” leftovers that still compile and remain reachable — the over-engineering that is neither unused nor single-path ceremony.

## Intent

Confirm two reachable paths for one behavior (or a reachable shim that only forwards to the surviving owner) and remove one path. A successful fix reports authored LOC, declarations, or exported API removed by deleting the superseded path — not by wrapping it again. A clean pass is valid. Planning and phasing: [README.md](README.md).

## What counts as dual-path retention

| Tell | Why it is a finding candidate |
|------|-------------------------------|
| Forwarding wrapper or rename-only typealias still imported beside the real owner | Extra name preserves a deleted API surface |
| Feature API on a hub that duplicates a handler/engine/store method | Callers can use either; hubs and owners drift |
| Migration / legacy bridge still on hot paths after the consumer window is closed | Temporary compatibility became permanent surface |
| Parallel implementations of the same rule or presentation after a refactor | “Keep both for safety” without a remaining distinct consumer |
| Deprecated entry that only exists to call the new entry | Reachable twin with no unique behavior |
| Permanent feature-flag or build-time switch that still ships both implementations of one behavior | Loser path has no remaining distinct consumer |

**Not this audit:** zero live consumers → DeadCode; single surviving name that is pure ceremony (no second reachable path) → InelegantSlop; wrong owner **and** leftover twin → StateGravity (move, then delete the old path); wrong owner without a twin → StateGravity; duplicate product screens / shells → DuplicateFeatureSurface; duplicate or over-expanded test harnesses asserting one rule → UnitTest or E2ETestQuality; live mass / mixed jobs on a single path → AuthoredMassGrowth; legacy `DispatchQueue` when isolation/data-race is the issue → SwiftConcurrencyDataRaceAudit; intentional seams (RNG injection, persistence coalescing, Options vs PlayerSave, catalog/codegen).

## Hard stops

- Do not collapse intentional dual seams listed in Architecture or sibling audits (battle RNG injection, persistence write coalescing, Options/`UserDefaults` vs `PlayerSave`, catalog authored vs generated).
- Do not delete a migration path while save or shell-session clients still require the old shape — confirm the consumer window is closed first.
- Do not rewrite battle pipeline math or save wire format under this audit; prove equivalence via existing package owners when a dual rule path is confirmed.
- Do not demote or delete package `public` API that is an intentional cross-package contract without the same consumer inventory DeadCode requires.
- Prefer the owning audit when the hit is primarily unused, ceremony-only (no twin), ownership drift (with or without a twin), duplicate UI, test-portfolio fit, authored mass on a single path, or concurrency isolation.

## Evidence bar

Either:

- **Two reachable paths** for one behavior (both compile-time referenced from product or tests), with one path able to absorb callers; or
- **Reachable no-op shim:** the shim / deprecated entry still has live references (product, tests, or exported API) but adds no unique behavior beyond forwarding to the surviving owner; callers can be retargeted and the shim deleted

Plus a delete-one-path remedy that preserves behavior. Speculative “might need later” is not evidence.

For migration / legacy-bridge tells, also confirm the consumer window is closed: inventory shows no remaining save / shell-session / schema consumer of the old shape, or Architecture / persistence docs mark the bridge obsolete. Speculative “enough time has passed” is not evidence.

DeadCode owns symbols with **zero** live consumers. This audit owns reachable twins or reachable no-op shims.

## Domain rules

Prefer delete the superseded path → retarget callers to the surviving owner → remove forwarding wrappers and rename-only typealiases → demote or delete leftover public API. Do not leave a pass-through “for compatibility” after callers move. Correct owner with leftover twin / shim → this audit; wrong owner with leftover twin → StateGravity. Significant package moves or new seams remain proposals per [README.md](README.md).

Successful fixes leave a single owner for the behavior and a net surface reduction.
