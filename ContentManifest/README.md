# Content Pipeline

Trinket keeps editable game content manifests separate from generated Swift catalogs.

## Folders

- `ContentManifest/affixes.tsv`: source of truth for item affix definitions.
- `ContentManifest/abilities.tsv`: manifest-driven abilities (`direct_hit`, `buff_only`, `multi_damage`).
- `ContentManifest/stages.tsv`: manifest-driven chapter stages, encounters, and rewards.
- `ContentManifest/combatants.tsv`: manifest-driven heroes and pets (ability choices + stats).
- `ContentManifest/enemies.tsv`: manifest-driven enemies (loadout + boss flags).
- `ContentManifest/item_bases.tsv`: manifest-driven weapon, armor, and trinket base types.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/ItemAffixCatalog.generated.swift`: generated affix catalog.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityCatalog{Basic,Skill,Ultimate}.generated.swift`: generated manifest abilities by tier.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityShorthand.generated.swift`: generated `extension Ability` shorthand.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentChapters.generated.swift`: generated journey chapters from `stages.tsv`.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentRoster.generated.swift`: generated heroes and pets from `combatants.tsv`.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEnemies.generated.swift`: generated enemies from `enemies.tsv`.
- `ContentManifest/homestead_nodes.tsv`: manifest-driven homestead nodes (one row per tier).
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentItemBases.generated.swift`: generated item base catalog.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEncounterArt.generated.swift`: generated stage encounter art overrides from `stages.tsv`.
- `Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalog{Basic,Skill,Ultimate}.swift`: custom abilities that do not fit manifest patterns.

## Manifest Formats

### Affixes (`ContentManifest/affixes.tsv`)

Tab-separated columns:

```text
id	title	slot	keywords	weight	basic_description	astral_description	basic_modifiers	astral_modifiers
```

- `slot`: `weapon`, `armor`, or `trinket`.
- `keywords`: comma-separated keyword names (e.g. `physical,bleed`).
- `*_modifiers`: pipe-separated DSL tokens (e.g. `strength:1|damage_dealt:physical:1`).

### Abilities (`ContentManifest/abilities.tsv`)

Tab-separated columns:

```text
pattern	symbol	id	name	tier	amount	keyword	description	effects	damage_components	extras
```

- `pattern`: `direct_hit`, `buff_only`, or `multi_damage`.
- `tier`: `basic`, `skill`, or `ultimate`.
- `description`: use `\n` for line breaks.
- `effects` / `extras`: pipe-separated effect DSL (e.g. `shield:block:2:6`, `instant_heal:health:3`).
- `damage_components`: pipe-separated `amount:keyword` or `amount:keyword:target` tokens.

Custom abilities with unusual targeting, multi-step combos, or description overrides stay in the hand-written tier Swift files.

### Stages (`ContentManifest/stages.tsv`)

Tab-separated columns:

```text
chapter_id	chapter_number	chapter_title	theme	stage_number	flavor_text	encounter	enemy_id	gold	item_templates	materials	encounter_art_id	encounter_art_title
```

- `theme`: chapter theme enum case (e.g. `verdantForest`).
- `encounter`: `battle`, `event`, `shop`, or `rest`.
- `enemy_id`: required for `battle`; empty otherwise.
- `item_templates`: comma-separated item template IDs.
- `materials`: pipe-separated `resource:amount` tokens (e.g. `wood:8|stone:3`).
- `encounter_art_id` / `encounter_art_title`: optional pair for non-battle stages; references `ArtCatalog.encounterArtByID`.

### Item bases (`ContentManifest/item_bases.tsv`)

Tab-separated columns:

```text
id	name	slot	keywords
```

- `slot`: `weapon`, `armor`, or `trinket`.
- `keywords`: comma-separated keyword affinities (e.g. `physical,bleed,poison`).

Roster catalogs are manifest-driven via `combatants.tsv` and `enemies.tsv`. Hand-written roster Swift files are thin wrappers over generated output.

### Combatants (`ContentManifest/combatants.tsv`)

Tab-separated columns:

```text
id	name	role	max_health	max_mana	basics	skills	ultimates	strength	agility	toughness	intellect	wisdom
```

- `role`: `hero` or `pet`.
- `max_mana`: `0` when unused.
- `basics` / `skills` / `ultimates`: comma-separated ability symbols (two choices per tier).
- Stats are non-negative integers.

### Enemies (`ContentManifest/enemies.tsv`)

Tab-separated columns:

```text
id	name	max_health	is_boss	level	abilities	strength	agility	toughness	intellect	wisdom
```

- `max_health`: `default` uses `Enemy.defaultMaxHealth`, or an explicit integer.
- `is_boss`: `true` or `false`.
- `abilities`: comma-separated ability symbols (basic, skill, ultimate — exactly three).

### Homestead nodes (`ContentManifest/homestead_nodes.tsv`)

Tab-separated columns:

```text
node_id	title	summary	symbol_name	tint	category	prerequisites	tier	cost	bonus_title	bonus_description
```

- `node_id`: `HomesteadNodeID` case name (e.g. `wheatField`).
- `tint`: `orange`, `green`, `yellow`, `mint`, `cyan`, `indigo`, or `blue`.
- `category`: `farming`, `crafting`, or `research`.
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

Validate manifests only:

```sh
./Scripts/validate-manifests.sh
```

Regenerate and verify committed output matches:

```sh
./Scripts/assert-generated-output.sh --regenerate
```

Legacy subcommands (`generate-content-catalogs.sh`, `generate-ability-shorthand.sh`) still work but print a notice to prefer `generate.sh`.

After changing manifests or custom tier files:

```sh
./Scripts/generate.sh
./Scripts/build.sh
```

Generated files are committed so the app builds without rerunning the generator. CI fails if catalog generated output under `Packages/TrinketContent/` drifts from the manifests.
