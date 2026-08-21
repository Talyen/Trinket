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

- `slot`: `weapon`, `armor`, or `trinket`.
- `keywords`: comma-separated keyword names (e.g. `physical,bleed`).
- `*_modifiers`: pipe-separated DSL tokens (e.g. `strength:1|damage_dealt:physical:1`). Empty when the affix is trigger-only.
- `*_triggers`: pipe-separated combat trigger tokens (e.g. `on_bleed_apply_poison:1`, `refresh_bleed_on_reapply:true`). Empty for flat modifier affixes.

### Talents (`ContentManifest/talents.tsv`)

Tab-separated columns:

```text
id	name	description	modifiers	triggers
```

- `id`: `{combatantID}_{keyword}_t{row}_{slot}` matching `CombatantTalentCatalog` tree nodes.
- `modifiers` / `triggers`: same pipe-separated DSL as affixes (`damage_dealt:physical:1`, `blockPerTurn:2`). CamelCase schema field names are accepted as trigger tokens.

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
- **List / understand all abilities:** read `Generated/AbilityInventory.generated.tsv` (`id`, `name`, `tier`, `summary`) or `AbilityCatalog.all` — not a ContentManifest TSV.

Combatant and enemy manifests still reference abilities by Swift symbol (e.g. `slash`, `fireball`).

Talent trees are authored in `ContentManifest/talents.tsv` using the same trigger/modifier DSL as affixes. Lookup/config API: `CombatantTalentCatalog.swift`. Generated dictionaries: `Packages/TrinketContent/Sources/TrinketContent/Generated/CombatantTalentCatalog.generated.swift`.

### Stages (`ContentManifest/stages.tsv`)

Tab-separated columns:

```text
chapter_id	chapter_number	chapter_title	theme	stage_number	encounter	enemy_id	encounter_art_id	encounter_art_title
```

- `theme`: chapter theme enum case (`forest`, `dungeon`, `desert`, `tundra`).
- `encounter`: `battle`, `random_battle`, `event`, `shop`, `rest`, `mystery`, or `recruit`.
- `enemy_id`: required for `battle` (enemy catalog id). For `mystery` / `recruit`, optional event id — empty mystery picks a random non-recruit event at runtime; empty recruit picks any eligible unlock; `random-companion` picks an eligible companion only. Leave empty for `random_battle` / shop / rest / event.
- Combat rewards (item / gold / materials) are resolved at runtime by `BattleLoot`, not authored here.
- `encounter_art_id` / `encounter_art_title`: optional pair for non-battle, non-mystery stages; references `ArtCatalog.encounterArtByID`. Mystery recruit stages use combatant portrait art instead.

### Item bases (`ContentManifest/item_bases.tsv`)

Tab-separated columns:

```text
id	name	slot	weapon_kind	keywords
```

- `slot`: `weapon`, `armor`, or `trinket`.
- `weapon_kind`: required for weapons (`one_handed`, `two_handed`, or `off_hand`) and empty otherwise.
- `keywords`: comma-separated keyword affinities (e.g. `physical,bleed,poison`).

Roster catalogs are manifest-driven via `combatants.tsv` and `enemies.tsv`. Hand-written roster Swift files are thin wrappers over generated output.

### Combatants (`ContentManifest/combatants.tsv`)

Tab-separated columns:

```text
id	name	role	max_health	max_mana	growth_archetype	basics	skills	ultimates	strength	agility	toughness	intellect	wisdom
```

- `role`: `hero` or `companion`.
- `max_mana`: `0` when unused.
- `basics` / `skills` / `ultimates`: comma-separated ability symbols (two choices per tier).
- Stats are non-negative integers.
- Primary-stat budget: `strength + agility + toughness + intellect + wisdom` must equal **50**.

### Enemies (`ContentManifest/enemies.tsv`)

Tab-separated columns:

```text
id	name	max_health	is_boss	growth_archetype	abilities	trait_id	faction
```

- `max_health`: `default` uses `Enemy.defaultMaxHealth`, or an explicit integer.
- `is_boss`: `true` or `false`.
- `faction`: `mortal`, `beast`, `elemental`, `construct`, `undead`, or `corrupted`.
- `abilities`: comma-separated ability symbols (basic, skill, ultimate — exactly three).
- Enemy primary stats come from `GrowthArchetype.identityPrimaryStats` (budget 50). Do not author per-enemy Strength/Agility/Toughness/Intellect/Wisdom.
- Boss difficulty comes from `is_boss` plus `EnemyPowerCurve` at encounter level (HP 2x trash; L1 boss stats 5.2, L20/L40 10.77/18.90).

### Homestead nodes (`ContentManifest/homestead_nodes.tsv`)

Tab-separated columns:

```text
node_id	title	summary	symbol_name	category	prerequisites	tier	cost	bonus_title	bonus_description	production
```

- `node_id`: `HomesteadNodeID` case name (e.g. `wheatField`).
- `category`: `farming`, `crafting`, `alchemy`, `training`, or `arcana`.
- `prerequisites`: pipe-separated `nodeID` or `nodeID:tier` tokens.
- `cost`: pipe-separated `resource:amount` tokens (e.g. `wood:10|stone:4`).
- One row per tier; node metadata must match across tiers for the same `node_id`.

Homestead catalogs are manifest-driven via `homestead_nodes.tsv`. Hand-written homestead Swift files are thin wrappers over generated output.

## Generate Catalogs

**Always use the orchestrator:**

```sh
./Scripts/generate.sh
```

This validates manifests, regenerates content catalogs and ability shorthand, and runs XcodeGen.

Regenerate and verify committed output matches HEAD (CI / pre-push):

```sh
./Scripts/assert-generated-output.sh --regenerate
```

For mid-task consistency after `./Scripts/generate.sh`, use
`./Scripts/assert-generated-output.sh --idempotent` (what `handoff.sh` runs).

Content-only regeneration (skip XcodeGen): `./Scripts/generate.sh --skip-xcodegen`.

After changing manifests or custom tier files:

```sh
./Scripts/generate.sh
./Scripts/build.sh
```

Generated files are committed so the app builds without rerunning the generator. CI fails if catalog generated output under `Packages/TrinketContent/` drifts from the manifests.
