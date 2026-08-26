---
type: execution-plan
status: complete
created: 2026-08-21
updated: 2026-08-25
expires: 2026-09-04
---

# Labyrinth Modifier Expansion + Forge Removal

## Context

The Labyrinth currently ships seven named node modifiers (five enemy-keyword damage boosts on battle/boss, Shop Discount on shops, Astral Seam on crafting altars). This plan removes the forge flow entirely and grows the modifier catalog to seventeen, using only existing combat plumbing (`AffixModifier` already maps every needed effect into `CombatModifierProfile`).

## Part A — Delete the Forge

Crafting Altars go away entirely ("not wanted for now"). Old saves must survive.

- `LabyrinthNodeType.craft` stays decodable but becomes legacy like `.event`: `canonical` maps it to `.mystery`. Load-time sanitization (`PlayerSaveLabyrinthMigration`) then re-types former altars automatically and re-resolves their modifiers.
- Delete: `forgeAtAltar`, `craftAltarCost`, forge item generation, `beginCraft`/`forgeActiveCraft`/`leaveActiveCraftWithoutForging`, `LabyrinthNodeSession` craft kind (session collapses to rest-only), `LabyrinthCraftView`, generator craft emission, catalog/stipend/UI craft branches.
- Delete **Astral Seam** and its `.astralChancePercent` effect case — its only host was craft nodes. Homestead astral-chance plumbing is independent and stays.

## Part B — New catalog (10 additions)

| id | Title | Effect | Nodes |
|---|---|---|---|
| sunTithe | Sun Tithe | +1 holy damage dealt | battle, boss |
| concussionToll | Concussion Toll | +1 stun damage dealt | battle, boss |
| bulwarkBargain | Bulwark Bargain | +2 Block gained | battle, boss |
| vampiricLedger | Vampiric Ledger | +5% Leech gained | battle, boss |
| wardedFlesh | Warded Flesh | −20% physical damage taken | battle, boss |
| frostboundWard | Frostbound Ward | −30% freeze damage taken | battle, boss |
| bountyMark | Bounty Mark | +25% Gold found | battle, boss, mystery |
| scholarsToll | Scholar's Toll | +25% XP earned | battle, boss, mystery |
| scavengersLuck | Scavenger's Luck | +25% Materials found | battle, boss, mystery |
| appraisersEye | Appraiser's Eye | Shop offers are all Astral | shop |

Assignment rules (`LabyrinthCatalog.modifierIDs(for:)`, salt-seeded, does not disturb map-layout RNG):

- **battle/boss**: one pick from a pool of keyword-matched modifiers (dealt or reduction matching the enemy's own keywords) plus keywordless ones (Bulwark, Vampiric, Bounty, Scholar, Scavenger).
- **shop**: seeded pick of Shop Discount or Appraiser's Eye (shops carry exactly one).
- **mystery**: every mystery node now carries exactly one of Bounty Mark / Scholar's Toll / Scavenger's Luck — same IDs as combat nodes, no separate names needed since assignment is per-node.

## Part C — Plumbing

- **Effects model**: new aggregated fields on `LabyrinthModifierEffects` mirror the new cases (damage-taken reduction map, block, leech %, gold/xp/materials %, astral-shop flag); `combining` aggregates them.
- **Combat**: `combatModifiers(from:)` translates reductions/block/leech into `[AffixModifier]` universal modifiers (fractions divided by 100).
- **Loot**: `BattleLoot.resolve` regains `goldPercent` and gains `materialsPercent`; `resolveLabyrinth` feeds both from node effects.
- **XP**: `LabyrinthCompletion.complete` passes `effects.experienceEarnedPercent` into the existing `grantBattleExperience(xpPercent:)`.
- **Mystery rewards**: `MysteryEffectApplier.apply` gains optional gold/XP/materials percent knobs; `MysteryEncounterSession.resolveChoice` fills them from the labyrinth node's effects when the encounter originated on the map.
- **Shops**: offer generation gains an all-Astral flag; `beginShopEncounter` reads both shop flags from node effects.

## Verification

Path-scoped gate (`handoff.sh --isolate`) over content/state/persistence/app-UI paths: style, TrinketContent + TrinketAppState + TrinketPersistence package suites, UI smoke. Test updates: floor-shape composition, keyword-pool assertions generalized for keywordless modifiers, forge/craft tests replaced by mystery-economy and shop-flag coverage, loot multiplier coverage.

## Status

Landed in the same working tree as [SimplificationCorrectnessPass](SimplificationCorrectnessPass.md), which made two compile completions on this plan's behalf mid-flight. In the tree now:

- **Part A**: `.craft` decodes as legacy and canonical-maps to `.mystery`; forge/session/craft-view/generator/catalog branches deleted (`LabyrinthCraftView` gone, `LabyrinthNodeSession` rest-only, `nonCombatGoldStipend` absorbs the former altar stipend); Astral Seam and `.astralChancePercent` removed.
- **Part C**: `LabyrinthModifierEffects` carries the aggregated fields (damage-taken map, block, leech %, gold/xp/materials %, `astralShopOffers`); `BattleLoot.resolve` takes `goldFoundPercent`/`materialsFoundPercent` with zero-default RNG-neutral behavior; `LabyrinthCompletion.complete` feeds `experienceEarnedPercent`; mystery reward knobs flow from `MysteryEncounterSession.mysteryRewardBonuses(in:)`; shop flags read from node effects.

Pending: full-repo `./Scripts/test.sh unit` sweep — previously blocked by the two plans splitting the tree; both now share it, so run before push.
