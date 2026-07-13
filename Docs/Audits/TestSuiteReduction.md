# Test Suite Reduction Audit

**Goal:** Reduce authored test declarations toward ~600–625 while preserving unique semantic owners and tier boundaries.

**Siblings:** unit quality → [UnitTestAudit.md](UnitTestAudit.md); UI/smoke/exhaustive → [E2ETestQualityAudit.md](E2ETestQualityAudit.md). Conventions: `Docs/Platform/Testing.md`. Battle ownership: `Packages/BattleEngine/Tests/README.md`.

## Intent

Confirm duplicate, weaker, or implementation-detail declarations with a stronger owner elsewhere, then make a bounded set of keep / merge / remove / tier-only changes. A clean pass is valid. Do not chase the band with low-confidence cuts.

## Hard stops

- Do not weaken `BattleStateTestFactory.makeBattle(..., rngSeed: 0)` / deterministic battle seeds.
- Do not remove `accessibilityIdentifier` values used by UI tests.
- XCTest remains for `TrinketUITests/` only; unit/package targets stay on Swift Testing.
- Preserve unique battle, persistence, balance, app-transition, and player-flow owners.
- Do not hide or delete failing UI journeys solely to reduce count; fix or keep as exhaustive owners.
- Do not invent wall-clock declaration budgets that conflict with Testing.md / `AGENTS.md` gates.

## Disposition vocabulary

- **keep** — unique semantic owner or required boundary/invariant coverage.
- **merge** — fold into a semantic matrix or cross-catalog invariant; the replacement owns the assertions.
- **remove** — duplicate, brittle implementation detail, or weaker example with stronger coverage elsewhere.
- **tier-only** — retain, but assign to one execution tier to prevent overlap (smoke vs exhaustive UI).

## Fix priority

**Tier 1:** Same assertion owned twice across suites; thin `BattleSession.outcome` / app-shell echoes of package resolver or store owners; exact catalog count / pixel-table / struct field round-trips with a stronger invariant nearby.

**Tier 2:** Merge sibling cases that differ only by one branch into `@Test(arguments:)` or one semantic matrix; move multi-step UI journeys out of smoke into exhaustive when smoke already has a canary.

**Tier 3 (only if quick):** Drop redundant exact-count lines inside an otherwise kept test (`clips.count == expected.count` when the ID loop already owns coverage).

## Domain rules

**Ownership (prefer these over weaker copies):**

| Concern | Prefer |
|---------|--------|
| Battle rules / handlers / pipelines | `Packages/BattleEngine/Tests/` matrix in that package’s README |
| Outcome resolution | `BattleOutcomeResolverTests` (+ card-combat phase owners); not thin session outcome echoes |
| Catalogs / content | Invariants, uniqueness, cross-domain art/registry parity — not exact `count == N` snapshots |
| Persistence write-through | `TrinketPersistenceTests` store / sanitizer / journey owners |
| App orchestration | `TrinketTests` shell / play-flow / session owners only when package tests cannot cover the seam |
| Design system | Public semantic tokens, contrast, motion contracts, path geometry — not material/shadow/padding details |
| UI tiers | Smoke = short canaries; exhaustive = multi-step journeys. `FullUI.xctestplan` must not auto-include smoke classes |

**Quality:** assert semantics (events, HP deltas, reload-from-disk, visible UI outcomes), not log fingerprints, pixel tables for common device widths, or property round-trips of plain structs.

**UI:** Prefer `-launch-screen` / launch args over navigation loops. One smoke theme per method. Long Play hierarchy journeys stay exhaustive-tier-only.

## Probe hints

Inventory: count `@Test` in package/`TrinketTests` plus `func test` in `TrinketUITests`. Compare against the prior band (~786 before this guide’s bounded passes).

Look for: duplicated names across BattleState vs CardCombat/Roster; `BattleSession` outcome cases that only re-wrap resolver/card-combat; exact `count == N` catalog snapshots; layout width→pixel tables; smoke screen-load overlap with stronger flow owners; `FullUI.xctestplan` / `Smoke.xctestplan` selectedTests drift.

Timing history (`./Scripts/test-timing.sh report`) is a lead for runtime, not proof a declaration is redundant.

## Verify

`lint.sh` + boundaries; focused `./Scripts/test-package.sh <Package>` for package cuts; focused `./Scripts/test.sh unit <Class>` for app cuts; `./Scripts/test.sh smoke <SmokeClass>` only if smoke/UI tiers changed. Skip simulator-backed checks when the toolchain is absent and state the skip.
