# Battle Card Combat Migration

Living tracking doc for migrating Trinket from a tick-based idle auto-battler to a turn-based card deckbuilder. Mechanical migration only — UI polish is a later pass.

**Status:** Complete (mechanical pass)

## Locked decisions

- **Player turn:** Play any number of hand cards. When no playable cards remain, the turn auto-ends after a short beat (~0.4s). All cards free (ignore `manaCost`).
- **Hand:** One shared hand; cards tagged Hero or Pet. Draw 1 Hero + 1 Pet each player turn (after opening hand). Soft cap **8**; at cap, skip that draw.
- **Decks:** Separate Hero deck and Pet deck from unlocked loadout abilities. Played card → bottom of its owner deck. No mulligan.
- **Opening hand:** Draw **2 Hero + 2 Pet** at battle start, then player’s first turn.
- **Enemy:** No hand/deck. One ability per enemy turn using old cadence (Basic / Skill every 3rd / Ultimate every 6th enemy turn). Player always first.
- **Time model:** No ticks/seconds. Durations: **1 former tick = 1 turn**. Effect tick + duration decrement once per **end of round** (after player turn + enemy turn).
- **Remove:** Pause entirely; `BattleSimulator` + entire `BattleBalanceTools` / `BalanceSweepCLI` / `Scripts/balance-sweep.sh` / related gates.
- **Keep dormant:** Mana fields in data; hide mana bars in battle UI for v1.
- **Haste:** No combat effect in v1 (action intervals gone). Agility keeps dodge/crit/bleed math only.
- **Control / Death's Door:** Keep; skip next act / duration in turns.
- **Dead owner:** Cards unplayable; stop draws for that owner. Both party dead → defeat; enemy dead → victory.
- **Spectacle:** Keep skill callouts / ultimate cinematics on play for now. Combatant tap-detail kept; hand-card tap-detail. No manual End Turn control.
- **Layout:** Portrait; reserve ~230pt bottom hand band for ~2× art-only ability cards; shrink battlefield grid; Hero/Pet/Enemy relative positions unchanged.

## Phase checklist

### Phase 0 — Plan + doc anchors

- [x] Create this tracking doc with locked decisions
- [x] Update `AGENTS.md` product line + doc path pointers (`Docs/Platform/*`, motion → `TrinketMotion`)
- [x] Link from `Docs/Platform/README.md`

### Phase 1 — Delete balance/sim tooling

- [x] Remove `BalanceSweepCLI` product/target from `Packages/BattleEngine/Package.swift`
- [x] Delete `Packages/BattleEngine/Sources/BattleBalanceTools/`
- [x] Delete `BattleSimulator.swift`; keep `BattleMatchup` / outcome types in `SimulationResults.swift`
- [x] Delete `Scripts/balance-sweep.sh`, `Scripts/assert-balance-gate.sh`
- [x] Delete obsolete sim/balance/golden-path/scheduling test suites

### Phase 2 — Turn/card engine core

- [x] Add `BattlePhase`, `BattleCard`, `CombatDeck`, `BattleHand`
- [x] Replace `advanceOneStep()` with `playCard(cardID:)` / `endTurn()`
- [x] Opening draw 2+2; per-turn draw 1+1; soft hand cap 8; play → bottom of owner deck
- [x] Rip `BattleLoopEngine`, `ActionSpeed` / interval scheduling, `nextReadyAtTick`
- [x] Wire `EffectTickEngine.tickAll` to end-of-round only; `tickCount` advances once per round
- [x] Enemy cadence AI (Basic / Skill@3 / Ultimate@6); ignore mana
- [x] Control skip: enemy skips turn; hero/pet cards unplayable that player turn, clear at end of player turn
- [x] Dead owner: unplayable + no draws

### Phase 3 — Ability translation

- [x] `EffectPresentation` / duration labels: seconds → turns
- [x] Ignore `manaCost` in resolution
- [x] Haste apply → no-op
- [x] Update presentation tests for turns copy

### Phase 4 — App session

- [x] Rewire `BattleSession` to `playCard` / `endTurn` + hand snapshots
- [x] Delete `AppState+BattleTickLoop.swift` and tick loop wiring
- [x] Remove all Pause APIs and UI

### Phase 5 — UI mechanical

- [x] Reserve hand band in `BattleCardGridLayout` (~230pt for art-only hand)
- [x] `BattleHandView` (fan) + drag-up to play + tap detail; full-bleed ability art, no on-card text
- [x] Auto-end turn when no playable cards (short beat); remove End Turn button / Pause toolbar
- [x] Hide mana bars in battle panes

### Phase 6 — Tests + docs cleanup

- [x] Delete obsolete tick/scheduling/pause tests
- [x] Rewrite turn/session/smoke tests for card driver
- [x] New deck/hand/phase package tests (`BattleCardCombatTests`)
- [x] Update `Docs/Platform/Architecture.md`, `Packages/BattleEngine/README.md`, root `README.md`

### Phase 7 — Verification

- [x] `./Scripts/test-package.sh BattleEngine` (287 tests passed)
- [x] `./Scripts/test-package.sh TrinketCore` (EffectPresentation turns)
- [x] `./Scripts/test.sh unit BattleSession` / `BattleCardGridLayout` / `AppState` / `BattleSpectacle` / `BattleVictory`
- [x] `./Scripts/test.sh smoke` + `SmokeBattle`
- [x] `./Scripts/check-ui-style.sh`

## Out of scope (later polish)

Card art/layout polish, mana economy, targeting UI, mulligan, enemy cards, haste redesign, rebalancing numbers, motion redesign beyond wiring existing spectacle.

**Follow-up:** headless balance simulator design lives in [`BattleBalanceSimulator.md`](BattleBalanceSimulator.md).
