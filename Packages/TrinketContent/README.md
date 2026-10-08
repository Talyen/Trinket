# TrinketContent

Game content catalogs — heroes, companions, enemies, abilities, items, stages,
homestead nodes, talent trees, and art/music/SFX references. Most
data content is manifest-driven (TSV → generated Swift). Abilities are authored
in Swift; talent trees are authored in `ContentManifest/talents.tsv`.

## Structure

- **Abilities/** — Ability models, validation, and authored `AbilityCatalog+Basic/Skill/Ultimate.swift` tier catalogs with ordered tier lists.
- **Equipment/** — Item and affix models, Unique catalogs, and loot generation.
- **Encounters/** — Journey, Spire, Contracts, Voyage, and shops; `Labyrinth/`, `Mystery/`, and `Rewards/` group their larger families.
- **Roster/** — Combatant models, equipment/keyword projections, and talent/trait lookup.
- **Homestead/** — Upgrade models, effects, and content lookup.
- **Media/** — Authored art, music, and sound lookup support.
- **Generated/** — Auto-generated catalogs from manifests, ability shorthand, talent dictionaries, and trigger-family structs (do not edit directly)

The source root holds `GameContent`, shared access policy, and trigger coding.
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
`Scripts/internal/content/modifiers.json`; `AffixModifier.swift` retains magnitude
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
| `ItemGenerator` | Random item generation from base + affix pools |
| `ThemedGearGenerator` | Legal worn equipment for headless balance simulations |
| `ShopOfferGenerator` | Procedural Merchant's Shop shelves (rarity + gold prices) |

Themed gear builds retain only equipped items. Candidate bases must satisfy the
same weapon-pair and duplicate-Trinket rules as `EquipmentLoadout`, so simulation
inventory and loadout metadata describe the same gear.

## Combat trigger value semantics

`CombatTraitTriggers` owns private copy-on-write storage. Its field payload uses
checked `Sendable` conformance, and all field mutations pass through one accessor
that ensures unique storage before writing. The wrapper's unchecked conformance
relies on this encapsulation; storage references must never escape the wrapper.

## Random item rewards

`ItemRewardGenerator` owns category selection and candidate filtering for battles,
shops, Mysteries, and Blacksmith forging. Tune level endpoints, tier weights,
curvature, and the boss multiplier in `Sources/TrinketContent/Equipment/ItemLootPolicy.swift`;
affix counts and keyword bias live with `ItemGenerator.swift`.
The loot policy blends the endpoint weights using normalized curved level
progression, clamped to levels 1–40. Bosses triple premium weights; Moonlit Sanctum multiplies
Astral weight by `1 + bonus/100`. After ownership, reservations, keywords, and
explicit pools remove unavailable categories, the remaining weights normalize.
There are no category-conversion fallbacks. Guaranteed Astral rewards constrain
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
Voyage destination offers also save a shared reward modifier for their final boss
reward. Missing offer modifiers decode as Bonus Gold.

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
Persistence's shared loot request resolves ownership once before rolling rewards;
battle launch captures the result for settlement. All modes reuse the same concise
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
