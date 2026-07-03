# Content Pipeline

Trinket keeps editable game content manifests separate from generated Swift catalogs.

## Folders

- `ContentManifest/affixes.tsv`: source of truth for item affix definitions.
- `ContentManifest/abilities.tsv`: manifest-driven abilities (`direct_hit`, `buff_only`, `multi_damage`).
- `ContentManifest/stages.tsv`: manifest-driven chapter stages, encounters, and rewards.
- `ContentManifest/combatants.tsv`: manifest-driven heroes and pets (ability choices + stats).
- `ContentManifest/enemies.tsv`: manifest-driven enemies (loadout + boss flags).
- `Packages/TrinketContent/Sources/TrinketContent/Generated/ItemAffixCatalog.generated.swift`: generated affix catalog.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityCatalog{Basic,Skill,Ultimate}.generated.swift`: generated manifest abilities by tier.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityShorthand.generated.swift`: generated `extension Ability` shorthand.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentChapters.generated.swift`: generated journey chapters from `stages.tsv`.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentRoster.generated.swift`: generated heroes and pets from `combatants.tsv`.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEnemies.generated.swift`: generated enemies from `enemies.tsv`.
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
chapter_id	chapter_number	chapter_title	theme	stage_number	flavor_text	encounter	enemy_id	gold	experience	item_templates	materials
```

- `theme`: chapter theme enum case (e.g. `verdantForest`).
- `encounter`: `battle`, `event`, `shop`, or `rest`.
- `enemy_id`: required for `battle`; empty otherwise.
- `item_templates`: comma-separated item template IDs.
- `materials`: pipe-separated `resource:amount` tokens (e.g. `wood:8|stone:3`).

Roster catalogs (heroes, pets, enemies) remain hand-authored in `GameContentRoster.swift` / `GameContentEnemies.swift` until a future manifest lands.

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
