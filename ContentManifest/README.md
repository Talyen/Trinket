# Content Pipeline

Trinket keeps editable game content manifests separate from generated Swift catalogs.

## Folders

Authored inputs (edit these):

- `ContentManifest/*.tsv`: affixes, talents, traits, stages, combatants, enemies, item bases, and homestead nodes — the editable source of truth for game content.
- `Packages/TrinketContent/Sources/TrinketContent/Content/`: authored ability catalogs.

Generated outputs (never hand-edit) live in
`Packages/TrinketContent/Sources/TrinketContent/Generated/`; `./Scripts/generate.sh`
regenerates them from the manifests.

## Manifest Formats

### Affixes (`ContentManifest/affixes.tsv`)

Tab-separated columns:

```text
id	title	slot	keywords	weight	basic_description	astral_description	basic_modifiers	astral_modifiers	basic_triggers	astral_triggers
```

- `slot`: `weapon`, `armor`, `accessory`, or `trinket`.
- `keywords`: comma-separated keyword names (e.g. `physical,bleed`).
- `*_modifiers`: pipe-separated DSL tokens (e.g. `maximum_health:6|damage_dealt:physical:1`). Empty when the affix is trigger-only.
- `*_triggers`: pipe-separated combat trigger tokens (e.g. `on_bleed_apply_poison:1`, `block_per_turn:2`). Empty for flat modifier affixes. Trailing trigger columns may be omitted (no trailing tabs required); extra columns are rejected.
- One value per field in a cell: repeating a modifier or trigger field is rejected, as are non-numeric amounts and unknown keywords. Trigger value types follow the schema field types.

Trigger tokens resolve against `Scripts/trigger_family_schema.json` (families → `Generated/*Triggers.generated.swift`): explicit aliases and multi-part parsers live in `Scripts/content_codegen_triggers.py`, otherwise `snake_case` maps to the schema field (`dodge_chance_bonus` → `dodgeChanceBonus`). `camelCase` schema field names are accepted everywhere, not only in talents. Separate fields with `|` — gluing two fields with `,` inside one token is rejected. When the same token exists as both a modifier and a trigger (e.g. `dodge_chance_bonus`), the column decides which one it becomes.

Merge semantics when trigger sources stack (schema `merge` op per field): `add` sums, `or` takes either, `max` takes the larger, `mul` multiplies (identity 1), `add_excess` adds only the excess over 1 (identity 1, for a few damage multipliers), `coalesce` keeps the later value, `union` merges the sorted set (only `bonusManaOnTurns`).

### Talents (`ContentManifest/talents.tsv`)

Tab-separated columns:

```text
id	name	icon_id	description	modifiers	triggers
```

- `id`: stable `{combatantID}_{keyword}_t{row}_{slot}` identity. The encoded position is historical; `CombatantTalentCatalog` owns explicit position overrides when nodes move. Preserve these IDs and existing purchases when reordering.
- `icon_id`: `lucide:name` for a bundled Lucide asset or `sf:name` for an SF Symbol. Choose against the talent's name and description, not its branch alone. [Game icon selections](../Docs/Product/GameIcons.md) explains the visual boundary. Generation rejects unqualified identifiers and missing Lucide assets.
- `modifiers` / `triggers`: same pipe-separated DSL as affixes (`damage_dealt:physical:1`, `blockPerTurn:2`). CamelCase schema field names are accepted as trigger tokens. Trailing `modifiers` / `triggers` columns may be omitted when empty.

Every Hero and Companion tree has two nodes in each of its first three rows,
then a seventh talent at row 4, slot 1. Existing eighth talents remain supported.
Keep talent descriptions around ten words and prefer thematic rule changes over
arbitrary activation conditions. Damage types use “deal [type] damage”; the
normal damaging hit produces its associated damage-over-time effect or control
buildup. Row position does not increase a talent’s power budget; see
[PD-013](../Docs/Product/Decisions.md).

### Enemy traits (`ContentManifest/traits.tsv`)

Tab-separated columns:

```text
id	name	description	modifiers	triggers
```

- One row per enemy trait. `modifiers` / `triggers` use the same pipe-separated DSL as affixes.
- Generates `GameContentTraits.generated.swift`.
- Enemy turn auras: `turn_random_damage_all_enemies:keywordA:keywordB:amount` rolls one keyword each turn and deals `amount` of that type to each living party member. `turn_freeze_all_enemies:amount` deals fixed Freeze damage every other turn.

### Abilities (Swift catalogs)

Abilities are authored only in:

```text
Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalogBasic.swift
Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalogSkill.swift
Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalogUltimate.swift
```

- Prefer `AbilityBuilder.directHit` / `buffOnly` / `multiDamage` for repeated shapes; use `Ability(...)` when you need custom targeting, mana, conditionals, or other knobs builders do not cover.
- After editing, run `./Scripts/generate.sh` to refresh `AbilityShorthand.generated.swift` and `AbilityInventory.generated.tsv`.
- **List / understand all abilities:** read `Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityInventory.generated.tsv` (`id`, `name`, `tier`, `summary`) or `AbilityCatalog.all` — not a ContentManifest TSV.

Combatant and enemy manifests still reference abilities by Swift symbol (e.g. `slash`, `fireball`).

Talent trees are authored in `ContentManifest/talents.tsv` using the same trigger/modifier DSL as affixes. Lookup/config API: `CombatantTalentCatalog.swift`. Generated dictionaries: `Packages/TrinketContent/Sources/TrinketContent/Generated/CombatantTalentCatalog.generated.swift`.

### Stages (`ContentManifest/stages.tsv`)

Tab-separated columns:

```text
chapter_id	chapter_number	chapter_title	theme	stage_number	encounter	enemy_id	encounter_art_id	encounter_art_title
```

- `theme`: chapter theme enum case (`forest`, `dungeon`, `desert`, `tundra`).
- `encounter`: `battle`, `random_battle`, `shop`, `mystery`, or `recruit`.
- `enemy_id`: required for `battle` (enemy catalog id, validated). For `mystery` / `recruit`, optional event id — empty mystery picks a random non-recruit event at runtime; empty recruit picks any eligible unlock; `random-companion` picks an eligible companion only. Named event ids are validated against the authored pools. Leave empty for `random_battle` / shop.
- Combat rewards (item / gold / materials) are resolved at runtime by `BattleLoot`, not authored here.
- `encounter_art_id` / `encounter_art_title`: optional pair for `shop` stages only; the id must exist in `ArtManifest/curated-assets.tsv`. Mystery recruit stages use combatant portrait art instead.

### Item bases (`ContentManifest/item_bases.tsv`)

Tab-separated columns:

```text
id	name	slot	weapon_kind	keywords
```

- `slot`: `weapon`, `armor`, `accessory`, or `trinket`.
- `weapon_kind`: required for weapons (`one_handed`, `two_handed`, or `off_hand`) and empty otherwise.
- `keywords`: comma-separated keyword affinities (e.g. `physical,bleed,poison`).

Roster catalogs are manifest-driven via `combatants.tsv` and `enemies.tsv`. The `GameContent` registry reads the generated catalogs directly.

### Combatants (`ContentManifest/combatants.tsv`)

Tab-separated columns:

```text
id	name	role	max_health	max_mana	basics	skills	ultimates
```

- `role`: `hero` or `companion`.
- `max_mana`: `0` when unused; combatants with `max_mana > 0` gain +1 Mana every two levels.
- `basics` / `skills` / `ultimates`: comma-separated ability symbols (four choices per tier).
- Player leveling is +1 HP per level above 1; authored `max_health`/`max_mana` are level-1 values.

### Enemies (`ContentManifest/enemies.tsv`)

Tab-separated columns:

```text
id	name	max_health	is_boss	abilities	trait_id	faction
```

- `max_health`: explicit positive integer; scaled at encounter level via `EnemyPowerCurve` normal/boss HP curves.
- `is_boss`: `true` or `false`.
- `faction`: `mortal`, `beast`, `elemental`, `construct`, `undead`, or `corrupted`.
- `abilities`: comma-separated ability symbols (basic, skill, ultimate — exactly three).
- Enemy damage scales via `EnemyPowerCurve` raw damage % curves. Interpolation and growth beyond the final anchor follow [battle-balance.md](../Docs/AgentContext/battle-balance.md); the final anchor is not an upper cap. Enemies have 0% Crit/Dodge and cannot gain guaranteed crit, evade, or trait crit/dodge effects.

### Homestead nodes (`ContentManifest/homestead_nodes.tsv`)

Tab-separated columns:

```text
node_id	title	summary	icon_id	category	prerequisites	tier	stage_name	cost	bonus_title	bonus_description	modifiers	production
```

- `node_id`: `HomesteadNodeID` case name (e.g. `wheatField`).
- `category`: `farming`, `crafting`, `alchemy`, `training`, or `arcana`.
- `prerequisites`: pipe-separated `nodeID` or `nodeID:tier` tokens.
- `stage_name`: concise, player-facing name for the node's construction stage; use no more than three words.
- `cost`: pipe-separated `resource:amount` tokens (e.g. `wood:10|stone:4`).
- `production`: one `resource:quantity` daily rate (e.g. `food:1`), or empty for no passive production. Each tier supplies its complete rate, not an increment over the previous tier.
- `modifiers`: affix-token combat bonuses for that tier. Default scope is hero and companion; prefix `hero.` / `companion.` to target one side. Combat tokens include `outgoing_damage_percent:0.02`, `incoming_damage_reduction_percent:0.02`, `dodge_chance_bonus:0.02` (all additive, rounded via `CombatRounding`). Homestead-only tokens: `astral_chance:N`, `gold_find:N`.
- One row per tier; node metadata must match across tiers for the same `node_id`.

Homestead catalogs are manifest-driven via `homestead_nodes.tsv`. The `GameContent` registry reads the generated catalogs directly; `HomesteadEffects` computes tier effects from them.

## Generate Catalogs

Single entry: `./Scripts/generate.sh` (content-only regeneration adds
`--skip-xcodegen`). Input→command routing, review steps, generation assertions,
and shared media-pipeline rules: [content-and-manifests.md](../Docs/AgentContext/content-and-manifests.md).
