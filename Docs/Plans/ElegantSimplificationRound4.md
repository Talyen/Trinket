---
type: execution-plan
status: active
created: 2026-08-29
updated: 2026-08-29
expires: 2026-09-12
---

# ElegantSimplificationRound4

## Objective

Repo-wide simplification removing duplication, accidental inconsistency, and sharding
overhead without player-visible gameplay change. Fights, cards, and map behave
identically; code that runs them gets smaller and more consistent.

## Non-goals / untouched

- Hitch-prevention budgets: 320 MiB artwork / 550 MiB process / 260 MiB cache cap
  `physicalMemory/24` floor 160 — not lowered
- Launch/imminent artwork pins kept
- `ItemAffixCatalog` chunking stays as type-checker workaround
- No VoiceOver for feedback chips
- Full `TrinketContent`/`TrinketFeatureSupport` package splits, CloudKit,
  full `CombatTriggerEngine` 17-file grouping remain deferred per Architecture.md

## Plan

### WS A — Content & artwork single source

- Generate `ArtCatalog.allImageNames` / `allImageNamesSet` from `content_codegen.py`
  and replace 7× enumeration in `PreparedArtworkCache.defaultPresentationImageNames`,
  `TrinketApp` priority builder, and tests.
- Make thumbnail derivable (`imageName + "_thumb"`) or generate via helper.
- Fix `sunder` art name inconsistency; add parity test abilities vs art keys.

### WS B — Battle engine consistency hardening

- Heal: single wisdom path via `HealingEngine`; delete `CombatantRuntime.heal` double-dip.
- Targeting: single `BattleTargetResolver` for 3 resolver sites.
- Lifecycle: collapse `BattlePhase` vs `BattleLifecyclePhase` to one source.
- Hand: unify `BattleHand`/`BattleHandBuffer` into single `Hand` type.
- Damage: fix `buildupDamage` exit invariant.

### WS C — Battle presentation consolidation

- `ResourceBar<Style>` for health/mana duplication.
- `CardArtwork` primitive for card shape/stroke/placeholder.
- Metrics via Environment, `TimelineView` throttling, feedback dedup.

### WS D — Damage pipeline snapshot

- `DamageResolutionSnapshot` built once at pipeline entry; steps read snapshot.
- Single `maxDrawAndPlayDepth` source; regression test for ordering.

### WS E — Build & script simplification

- `prepare-assets.sh --kind` replacing 4 entry points.
- `FullUI` drift check mirroring smoke.
- Simulator docs state machine; keep classification scripts as-is.

### WS F — Small correctness nits

- `swift_escape` order fix, `Image.preparedAsset` miss logging, `nextEventID` start.

## Verification

Each WS via `Scripts/handoff.sh --isolate --paths <touched>` + `ci-gate.sh --fast`.
Full `test.sh unit` before push.

## Notes

Fold durable rules into `Docs/Platform/*` on completion. Move to `Docs/Plans/Archived/`
with `status: complete` when done.
