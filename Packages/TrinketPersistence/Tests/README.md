# TrinketPersistence Tests

Test ownership for `Packages/TrinketPersistence/Tests/TrinketPersistenceTests/`.

Store I/O tests isolate `@MainActor` on the test that opens `PlayerSaveStore`, not the suite. Value-type sanitizer, loot, and homestead math stay off the main actor so they can run in parallel. Write-through proofs still follow the mutate → reload-from-disk rubric in [Testing.md](../../../Docs/Platform/Testing.md).

| Concern | Owner | Notes |
|---------|-------|-------|
| SwiftData graph / hub | `PlayerSaveStoreTests` | Root creation, reset, seed, relaunch, independent records, snapshot validation, deferred flush |
| Schema migration | `PlayerSaveSchemaMigrationTests` in `PlayerSaveStoreTests.swift` | Lightweight migration when an entity is removed |
| Store cleanup / duplicate roots | `PlayerSaveStoreCleanupTests` | Sidecar wipe, `resetState`, newest-primary repair |
| Graph identity | `PlayerSaveGraphIdentityTests` | Persistent IDs survive in-place updates |
| Graph repair | `PlayerSaveGraphRepairTests` | Duplicate/orphan row repair on load |
| Sanitize on load | `PlayerSaveSanitizeOnLoadTests` | Dirty rows persist cleaned after open |
| Slice-scoped sanitize | `PlayerSaveSliceSanitizerTests` | Scoped vs full sanitize; persist-target expansion |
| Sanitizer (in-memory) | `PlayerSaveSanitizerTests` | Inventory, roster, journey, homestead, talents, progressions |
| World seed | `PlayerSaveWorldSeedTests` | Assign-once seed; labyrinth backfill |
| Starter selection | `StarterSelectionTests` | Draft/complete reload; schema grandfathering |
| Homestead store API | `PlayerHomesteadStoreTests` | `buildOrUpgradeNode` / `collectProduction` through the hub |
| Homestead math | `HomesteadStateTests` | Build costs, production settlement (no store I/O) |
| Roster / inventory state | `PlayerRosterStateTests` | Loadouts, equipment, gold, equipped-item lookup |
| Inventory decode | `InventoryModelMappingTests` | Trinket catalog refresh from stale rows |
| Unique items | `UniqueItemRuleTests` | Unique affix-power reload; altar exclusion |
| Talents | `TalentPersistenceTests` | Sanitizer filter, unlock API, reload |
| Journey progression | `JourneyProgressTests` | Unlock chain, `nextStage`, pin/progress reload, duplicate-stage repair |
| Stage rewards | `StageRewardTests` | Claim policy, gold/XP, party-adjusted claim fallback (journey + spire) |
| Combat loot rolls | `BattleLootTests` | Quantity bands, rarity ladder, seed-stable journey loot |
| Shop | `ShopPurchaseApplierTests` | Purchase rules; one cross-applier reload proof |
| Mystery apply | `MysteryEffectApplierTests` | Gold/materials/XP/items/recruits |
| Mystery pins | `MysteryEventPinApplierTests` | Journey/labyrinth pin idempotency |
| Mystery pick context | `MysteryEventPickContextSaveTests` | Corruption Altar gating |
| Salvage | `ItemSalvageApplierTests` | Yields, unequip, trinket/unique ineligibility, one reload |
| Corruption | `ItemCorruptionTests` | Affix rules, eligibility, one reload |
| Spires progress | `SpiresProgressTests` | Floor unlock/clear; XP override |
| Slice reload proofs | `SlicesReloadTests` | Spire clamp, ability loadouts, legacy companion armor |
| Labyrinth map / completion | `LabyrinthProgressTests` | Generation, clear, sanitize, completion, map+run-health reload |
| Labyrinth run health | `LabyrinthRunHealthTests` | Campfire math and payload decode (no extra store open) |
| Labyrinth encounter level | `LabyrinthEncounterLevelOverrideTests` | Loot/XP at overridden levels |
| Labyrinth migration | `LabyrinthMigrationTests` | Map version ID migration |
| Labyrinth unreadable blob | `LabyrinthSaveRecoveryTests` | Keep stored blob; do not regenerate on enter |

Harnesses: `Support/PersistenceTestContext.swift` (temp dir per store-test instance) and `TrinketPersistenceTestSupport.SaveTestSupport` (`writeRoot`, `makeGeneratedItem`, store factory).
