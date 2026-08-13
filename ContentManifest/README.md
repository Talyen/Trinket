# Content Pipeline

Trinket keeps editable game content manifests separate from generated Swift catalogs.

## Folders

- `ContentManifest/affixes.tsv`: source of truth for item affix definitions.
- `ContentManifest/stages.tsv`: manifest-driven chapter stages, encounters, and rewards.
- `ContentManifest/combatants.tsv`: manifest-driven heroes and companions (ability choices + stats).
- `ContentManifest/enemies.tsv`: manifest-driven enemies (loadout + boss flags).
- `ContentManifest/item_bases.tsv`: manifest-driven weapon, armor, and trinket base types.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/ItemAffixCatalog.generated.swift`: generated affix catalog.
- `Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalog{Basic,Skill,Ultimate}.swift`: authored abilities (all tiers).
- `Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityShorthand.generated.swift`: generated `extension Ability` shorthand.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityInventory.generated.tsv`: generated full ability list (`id`, `name`, `tier`, `summary`) for humans/agents. `summary` is `Ability.summary` (player-facing effect text).
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentChapters.generated.swift`: generated journey chapters from `stages.tsv`.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentRoster.generated.swift`: generated heroes and companions from `combatants.tsv`.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEnemies.generated.swift`: generated enemies from `enemies.tsv`.
- `ContentManifest/homestead_nodes.tsv`: manifest-driven homestead nodes (one row per tier).
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentItemBases.generated.swift`: generated item base catalog.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEncounterArt.generated.swift`: generated stage encounter art overrides from `stages.tsv`.

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
id	name	role	max_health	max_mana	growth_archetype	basics	skills	ultimates	strength	agility	toughness	intellect	wisdom	trait_id
```

- `role`: `hero` or `companion`.
- `max_mana`: `0` when unused.
- `basics` / `skills` / `ultimates`: comma-separated ability symbols (two choices per tier).
- Stats are non-negative integers.
- Primary-stat budget: `strength + agility + toughness + intellect + wisdom` must equal **50**.

### Enemies (`ContentManifest/enemies.tsv`)

Tab-separated columns:

```text
id	name	max_health	is_boss	growth_archetype	abilities	strength	agility	toughness	intellect	wisdom	positive_trait_id	negative_trait_id
```

- `max_health`: `default` uses `Enemy.defaultMaxHealth`, or an explicit integer.
- `is_boss`: `true` or `false`.
- `abilities`: comma-separated ability symbols (basic, skill, ultimate — exactly three).
- Primary-stat budget: `strength + agility + toughness + intellect + wisdom` must equal **50** for all combatants.
- Boss difficulty comes from `is_boss` plus `EnemyPowerCurve` at encounter level, not separate HP/stat bands.

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

Validate manifests only:

```sh
./Scripts/validate-manifests.sh
```

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
