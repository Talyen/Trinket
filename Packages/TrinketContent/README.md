# TrinketContent

Game content catalogs — heroes, companions, enemies, abilities, items, stages,
homestead nodes, talent trees, and art/music/SFX references. Most
data content is manifest-driven (TSV → generated Swift). Abilities are authored
in Swift; talent trees are authored in `ContentManifest/talents.tsv`.

## Structure

- **Abilities/** — Ability models, validation, and authored `AbilityCatalog+Basic/Skill/Ultimate.swift` tier catalogs with ordered tier lists.
- **Equipment/** — Item and affix models, Unique catalogs, loot generation, duplicate ownership, Corruption, and Salvage rules.
- **Encounters/** — Journey, Spire, Contracts, Voyage, and shops; `Labyrinth/`, `Mystery/`, and `Rewards/` group their larger families.
- **Roster/** — Combatant models, combat builds and build resolution, modifier profiles, level scaling, player roster state and edit rules, equipment/keyword projections, and talent/trait lookup.
- **Homestead/** — Player value state, production/collection and upgrade rules, effects, and content lookup.
- **Media/** — Authored art, music, and sound lookup support.
- **Generated/** — Auto-generated catalogs from manifests, ability shorthand, talent dictionaries, and trigger-family structs (do not edit directly)

The source root holds `GameContent`, shared access policy, trigger coding, and
`CombatReaction`, the shared localized reaction vocabulary consumed by the engine
and battle presentation. Reaction rules and progress remain in BattleEngine.
Domain-specific `GameContent` extensions live beside their models and catalogs.
`Sources/TrinketContentTestSupport/` is the shared support target for
combat/content/battle-party test fixtures (`CombatantFixtures`,
`ItemFixtures`, `BattlePartyFixtures`) that `TrinketContentTests` and the
other packages' test targets consume without a package cycle.
`Sources/AbilityInventoryDump/` and `Sources/LootBalanceReport/` are separate
tooling executable targets for generation and loot analysis. The domain folders
under `Sources/TrinketContent/` remain in the main target.

## Manifest sources

Schemas and input/output ownership live in
[`ContentManifest/README.md`](../../ContentManifest/README.md) and the matching
media-manifest READMEs. `Generated/` is the output of `./Scripts/generate.sh`;
do not maintain a second generated-file inventory here. Abilities remain
authored in the three `Abilities/AbilityCatalog+*.swift` tier files; trigger-family
schemas are indexed by `Scripts/internal/content/trigger_families/index.json`.
Modifier cases and mechanical transforms are generated from
`Scripts/internal/content/modifiers.json`; `ItemAffixPower+Rolling.swift` owns magnitude
bump policy. Historical item-power normalization lives in
`Equipment/InventoryItem+Compatibility.swift`: trigger migrations share one
normalization pass; modifier and catalog-backed Unique migrations stay separate.

## Adding content

```sh
# Edit the relevant TSV, then:
./Scripts/generate.sh
./Scripts/handoff.sh --isolate --quiet --paths <changed-files...>
```

Generated files are committed so the app builds without rerunning the generator.
Review the outputs alongside their authored inputs. Routine local handoff defers
compilation, content tests, and idempotence proof to CI under
[Verification](../../Docs/Platform/Verification.md#generated-project-consistency).

## Key types

| Type | Role |
|------|------|
| `GameContent` | Central registry for all game content |
| `Ability` / `TargetedEffect` | Ability model with effect declarations |
| `Combatant` | Hero/Companion model (stats, ability loadout) |
| `Enemy` | Enemy model |
| `CombatBuild` / `CombatBuildResolver` | Resolves combatants, equipment, and talents into modifier profiles and effective max stats |
| `CombatModifierProfile` / `CombatantMaxValues` | Shared build modifiers and maximum Health/Mana calculations; BattleEngine adds active-effect stack totals |
| `EncounterScaling` | Shared mode-specific encounter level and enemy power-profile policy |
| `ItemGenerator` | Random item generation from base + affix pools |
| `ThemedGearGenerator` | Legal worn equipment for headless balance simulations |
| `ShopOfferGenerator` | Procedural Merchant's Shop shelves (rarity + gold prices) |

Themed gear builds retain only equipped items. Candidate bases must satisfy the
same weapon-pair and duplicate-Trinket rules as `EquipmentLoadout`, so simulation
inventory and loadout metadata describe the same gear.
Trinkets use their authored singleton powers and rarity, independent of the
ordinary gear tier's affix count. Build alignment checks a Trinket's own signature.

## Combat trigger value semantics

`CombatTraitTriggers` owns private copy-on-write storage. Its field payload uses
checked `Sendable` conformance, and all field mutations pass through one accessor
that ensures unique storage before writing. The wrapper's unchecked conformance
relies on this encapsulation; storage references must never escape the wrapper.

## Encounter boards

`ContractBoard` and `VoyageBoard` own offer repair, generation, and replacement
from explicit pinned offers, retirement identities, access, and eligible rewards.
Voyage selection accepts a random generator; Contracts retains its offer-factory
injection. These rules need no save store. Persistence owns serialized state,
refresh admission, active runs, and completion/abandonment receipts. Preparing an
existing valid board retains its pinned offers; replacing a retired offer preserves
the other slots. Save fields and offer identifiers retain their existing formats.

## Random item rewards

`ItemRewardGenerator` owns category selection and candidate filtering for battles,
shops, Mysteries, and Blacksmith forging. Tune level endpoints, tier weights,
curvature, and the boss guarantee in `Sources/TrinketContent/Equipment/ItemLootPolicy.swift`;
affix counts and keyword bias live with `ItemGenerator.swift`.
The loot policy blends the endpoint weights with smoothstep `x² × (3 − 2x)`, where
`x = (clamp(level, 1, 40) - 1) / 39`. This delays early rare drops while preserving
level-1 and level-40 weights. Ordinary rewards use those weights; Moonlit Sanctum multiplies
Astral weight by `1 + bonus/100`. After ownership, reservations, keywords, and
explicit pools remove unavailable categories, the remaining weights normalize.
Boss victories instead guarantee an uncollected Trinket or Unique. With both categories
available, Unique chance is `5% + 45% × smoothstep(x)` and Trinkets receive the remainder;
the odds reach 50/50 at level 40. Selection is uniform within the selected full catalog.
A completed category leaves the other
at 100%; both complete guarantees Astral equipment. Boss collectible selection ignores
keyword restrictions, Sanctum, and item-tier weighting. The opening Journey boss's first
reward claim guarantees an uncollected Trinket, falling back to the regular boss rule
when Trinkets are complete. Existing claimed Journey rewards receive no retroactive award.
Bosses never drop Basics. Guaranteed Astral rewards constrain
the same resolver to Astral gear; exact authored item rewards remain exact.

Battle items roll at that battle's captured encounter level, with tier odds capped
at loot level 40. Shop, Mystery, and Blacksmith item quality uses the highest
encounter level won, also capped at 40. Existing saves
derive a floor from completed Campaign stages, Spire floors, and cleared Labyrinth
battles. Roster leveling without a victory does not advance noncombat offer quality; see
[Contracts](../../Docs/Product/Contracts.md#board) and
[Voyage](../../Docs/Product/Voyage.md#levels-and-rewards). Voyage shops and
Mysteries use the same highest-won level; their offers persist by run
and node identity.
Battle currency and experience continue to use the encounter level beyond the
item-quality cap. Saved items
and pinned offers retain their contents; newly generated rewards use current tuning.

From the repository root, produce the exact balance report with:

```sh
swift run --package-path Packages/TrinketContent LootBalanceReport
```

By default, the command saves the complete Markdown table in a unique directory
under `.DerivedData/LootBalanceReports/` and prints its absolute path and coverage.
Use `--output <path>` to choose the report file, or `--full` for the complete table
on stdout. `--full` alone writes no artifact; combining it with `--output` does both.

The 2,000-row report covers levels 1–40, both profiles, all Sanctum bonuses, category
exhaustion, shops, and guaranteed Astral rewards. Its cumulative chances assume
unchanged inputs and pool availability across the displayed reward count.

## Roster rules

`PlayerRosterState` owns party selection, selected abilities, equipment ownership,
progression, and talents. Its ID-based edits accept explicit access and owned
inventory values; rejected edits leave the roster unchanged. `EquipmentLoadout`'s
shared ownership rule transfers a physical item to the edited combatant and resolves
repair ties by combatant ID and slot order. These rules have no save-store dependency.
Persistence supplies current transaction inputs, maps the saved graph, migrates
retired ability IDs, sanitizes loaded state, and durably commits accepted edits.
Roster rule tests live here; storage failure and reload proofs stay in Persistence.

## Homestead rules

`PlayerHomesteadState` owns production timing, fractional credit, collection,
affordability, and upgrades. It accepts Gold values rather than saved rosters;
`TrinketCore.GoldBalance` supplies the shared wallet bound. Persistence owns
sanitization, graph mapping, transaction admission, and economic receipts.
The value's Codable fields are preserved for existing cloud snapshots.

## Mystery rewards

`MysteryRewardResolver` owns item-pool generation, reward scaling, Homestead
fractions, and offer settlement. Its captured inputs are `RewardOwnership`,
`HomesteadEffects`, and `RewardSettlementInputs`; it needs no player-save graph.
Persistence projects those inputs, pins offers, validates encounter admission,
and applies each result within the save transaction. Direct effect sequences
refresh inputs after each mutation so later rewards see updated ownership and XP.

## Item transformations

`InventoryDuplicatePolicy` owns physical-instance, Trinket, and Unique ownership
for inventory admission and repair. `BlacksmithForgePlan` resolves recipe eligibility,
rolls one item from explicit reward level and inventory values, and revalidates
current Homestead resources and ownership before charging. The plan retains that
same item across save retries; Persistence maps saved inputs and records the commit.

`ItemCorruption` accepts item values and inventory arrays; `ItemSalvage` computes
material yields from an item. These rules and Corruption result values have no
save-store dependency. Persistence applies their results within its transaction
boundary and owns receipts and encounter cooldowns.

Corruption gives each successfully added or replaced affix one numeric bump at the
item's final rarity: increase/decrease odds use the existing 40:20 weights (two to
one), changing one eligible value by 1 or one percentage point. A decrease that
cannot respect the 1 / 1% minimum becomes an increase. On/off affixes stay eligible
without a numeric bump. The independent item-wide 40% increase and 20% decrease
rolls target only surviving original affixes, preventing extra bumps on new affixes.
Existing corrupted items are unchanged; structural selection and corruption-mark
priority retain their existing rules. Items with affixes absent from the current
catalog remain saved intact and are ineligible for corruption; the altar must not
partially rebuild their affixes or powers.

## Shared reward modifiers

`RewardModifier` owns 13 quantity/material/item-tier bonuses, seven item-family
or tier guarantees, and 17 keyword item guarantees shared by Contracts and
node modifiers in Labyrinth, Voyage, and Spires. Contract
saves retain their `rewardModifier` field and existing string values; keyword
values use `keyword.<keyword>` (including `keyword.deathsDoor`). Labyrinth/Voyage
retain saved modifier IDs, including `bountyMark`, `scholarsToll`, and
`scavengersLuck`. Existing maps/routes are not rerolled. Each Spire floor derives
one keyword-matched node modifier from the saved world seed and its floor identity,
so no new save field is required.
Boss generation excludes item-focused modifiers; legacy saved boss item modifiers resolve
to Bonus Gold in presentation and payout without rewriting IDs. This includes Hard
Contracts and boss nodes. Voyage destination offers retain their independent reward
modifier; missing offer modifiers decode as Bonus Gold.

Keyword rewards choose uniformly among non-Trinket bases that have the advertised
keyword affinity and a positive-weight eligible affix for it. Generation reserves
one normal affix slot using matching affix weights, then rolls remaining slots
normally. Only Basic/Astral tiers participate, with their existing relative weights.
The strict `requiredKeyword` input is separate from probabilistic `keywordBias`;
missing matching content must never silently produce unrelated equipment.

Rare-tier modifiers double the selected eligible tier's weight. Combat nodes still
receive one modifier. `NodeModifierCatalog.originalCombatIDs` anchors the category
odds: the reward category has weight three against the count of originally eligible
combat effects for that enemy. Expanding either catalog does not dilute the other
category. Combat selection is uniform within the current eligible pool. Labyrinth
reward selection is uniform; Voyage first favors its
[chapter keyword affinity pool](../../Docs/Product/Voyage.md#route-generation),
then selects uniformly within the chosen pool, excluding its preceding modifier
when another entry exists there. Contracts select uniformly among eligible rewards.
New combat rewards do not enter Mystery or Shop pools; the original three Mystery
reward bonuses remain supported.

Arms, Armor, Ring, and Amulet Hoards restrict the ordinary single item to that
base family and Basic/Astral tiers. Astral, Trinket, and Unique Hoards guarantee
their named tier rather than changing its weight. Secondary equipment positions
share these base families, so they do not have separate modifiers. Trinket/Unique
guarantees are excluded once their unowned pool is empty; saved exhausted IDs
resolve to Bonus Gold without changing the saved ID.

Generation excludes exhausted Trinket/Unique rewards. A saved exhausted reward
resolves to Bonus Gold for presentation and payout without rewriting its ID.
Content's `BattleLootContext` owns mode-specific loot selection from a captured
world seed, `RewardOwnership`, and Sanctum bonus. `BattleLoot` rolls its `LootRequest`
for seeded Gold, materials, and items. Voyage's final destination composition,
bonus item roll, and last-collectible Gold conversion live in that same value-only
owner. Every item-focused Voyage destination adds a separate modifier-driven item beside
the boss guarantee, even without an item-focused node modifier. Basic is excluded from
that bonus; family and keyword guarantees therefore produce Astral gear. The bonus
respects ownership including the primary item; newly exhausted collectible modifiers
convert to Gold. Persistence adapts saved inputs and commits awards and claims; battle launch
captures the result for settlement. All modes reuse the same concise
reward descriptions and keyword/resource icons and colors.

## Labyrinth floor layout

New floors contain 15–20 nodes, including the entry battle and boss, within the
existing three-column hex envelope. Floors have 10–13 rows containing one or two
nodes; approximately half the rows contain two. Entry and boss rows contain one node.
Connected layouts have single-neighbor entry and boss nodes and at most four
neighbors per node. Generation chooses trees 60% of the time, single loops 20%,
and two-loop layouts 20%. Existing saved floors retain their geometry.
The map targets 20% larger hex dimensions where the actual floor span permits,
then caps sizing to keep selected seals inside the viewport without horizontal scrolling.
