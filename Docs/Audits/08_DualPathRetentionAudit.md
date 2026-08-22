# 08. Dual-Path & Compatibility Retention Audit

**Goal:** Delete confirmed parallel live implementations, migration shims past their window, and “keep both” leftovers that still compile and remain reachable — the over-engineering that is neither unused nor single-path ceremony.

## Intent

Confirm two reachable paths for one behavior (or a reachable shim that only forwards to the surviving owner) and remove one path plus its retained compatibility envelope. Equivalent behavior may use different API shapes; an obvious forwarding wrapper is not required. A successful fix reports authored LOC, declarations, configuration, tests, documentation, or exported API removed by deleting the superseded path — not by wrapping it again.

## What counts as dual-path retention

| Tell | Why it is a finding candidate |
|------|-------------------------------|
| Forwarding wrapper or rename-only typealias still imported beside the real owner | Extra name preserves a deleted API surface |
| Feature API on a hub that duplicates a handler/engine/store method | Callers can use either; hubs and owners drift |
| Migration / legacy bridge still on hot paths after the consumer window is closed | Temporary compatibility became permanent surface |
| Parallel implementations of the same rule or presentation after a refactor | “Keep both for safety” without a remaining distinct consumer |
| Deprecated entry that only exists to call the new entry | Reachable twin with no unique behavior |
| Permanent feature-flag or build-time switch that still ships both implementations of one behavior | Loser path has no remaining distinct consumer |
| Parallel behavior expressed through different APIs, configuration keys, or entry points | Shape differences conceal one duplicated shipping outcome and let callers drift |

**Not this audit:** intentional seams recorded as accepted non-findings in [Proposals.md](Proposals.md). Routing for zero-consumer symbols, pure-ceremony names, and wrong-owner hits follows the [confusable-pairs table](README.md#confusable-pairs).

## Hard stops

- Do not collapse seams recorded as accepted non-findings in [Proposals.md](Proposals.md) or prescribed by Architecture.
- Do not delete a migration path while save clients still require the old shape — confirm the consumer window is closed first.
- Do not rewrite battle pipeline math or save wire format under this audit; prove equivalence via existing package owners when a dual rule path is confirmed.
- Do not demote or delete package `public` API that is an intentional cross-package contract without the same consumer inventory DeadCode requires.

## Evidence bar

Either:

- **Two reachable paths** for one behavior (both compile-time referenced from product or tests), with one path able to absorb callers; or
- **Reachable no-op shim:** the shim / deprecated entry still has live references (product, tests, or exported API) but adds no unique behavior beyond forwarding to the surviving owner; callers can be retargeted and the shim deleted

Plus a delete-one-path remedy that preserves behavior and removes or migrates the associated callers, flags, tests, configuration, and documentation. Speculative “might need later” is not evidence.

For migration / legacy-bridge tells, also confirm the consumer window is closed: inventory shows no remaining save / schema consumer of the old shape, or Architecture / persistence docs mark the bridge obsolete. Speculative “enough time has passed” is not evidence.

DeadCode owns symbols with **zero** live consumers. This audit owns reachable twins or reachable no-op shims.

## Domain rules

Prefer delete the superseded path → retarget callers to the surviving owner → remove flags, configuration, tests, docs, forwarding wrappers, and rename-only typealiases → demote or delete leftover public API. Do not leave a pass-through “for compatibility” after callers move.

Successful fixes leave a single owner for the behavior and a net surface reduction.
