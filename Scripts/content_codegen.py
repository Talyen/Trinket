#!/usr/bin/env python3
"""Coordinate content validation and generation; domain owners live in internal/content."""

from __future__ import annotations

import sys
from dataclasses import dataclass

from internal.content.modifier_schema import generate_modifiers
from internal.content.affix_rolling import generate_affix_rolling

from internal.content.abilities import (
    collect_ability_symbols,
    collect_ability_tiers,
    generate_ability_inventory,
    generate_ability_shorthand,
)
from internal.content.content_codegen_triggers import _trigger_families
from internal.content.content_codegen_triggers import generate_trigger_families, generate_trigger_root
from internal.content.homestead import (
    HomesteadNodeRow,
    generate_homestead_catalog,
    parse_homestead_node_rows,
    validate_homestead_node_rows,
)
from internal.content.items import (
    AffixRow,
    ItemBaseRow,
    generate_affix_catalog,
    generate_item_bases_catalog,
    parse_affix_rows,
    parse_item_base_rows,
    validate_affix_reachability,
    validate_affix_rows,
    validate_item_base_rows,
)
from internal.content.roster import (
    CombatantRow,
    EnemyRow,
    TraitRow,
    generate_enemies_catalog,
    generate_roster_catalog,
    generate_traits_catalog,
    parse_combatant_rows,
    parse_enemy_rows,
    parse_trait_rows,
    validate_combatant_rows,
    validate_enemy_rows,
    validate_trait_rows,
)
from internal.content.stages import (
    StageRow,
    collect_art_ids,
    collect_mystery_event_ids,
    collect_recruit_event_ids,
    generate_chapters_catalog,
    generate_encounter_art_catalog,
    generate_stages_index,
    parse_stage_rows,
    validate_stage_rows,
)
from internal.content.talents import (
    TalentRow,
    generate_talent_catalog,
    parse_talent_rows,
    validate_talent_rows,
)


@dataclass
class ManifestRows:
    affixes: list[AffixRow]
    traits: list[TraitRow]
    stages: list[StageRow]
    combatants: list[CombatantRow]
    enemies: list[EnemyRow]
    homestead: list[HomesteadNodeRow]
    item_bases: list[ItemBaseRow]
    talents: list[TalentRow]

    def summary(self) -> str:
        return (
            f"{len(self.affixes)} affixes, {len(self.traits)} traits, "
            f"{len(collect_ability_symbols())} abilities, {len(self.stages)} stages, "
            f"{len(self.combatants)} combatants, {len(self.enemies)} enemies, "
            f"{len(self.homestead)} homestead tiers, {len(self.item_bases)} item bases, "
            f"{len(self.talents)} talents"
        )


def validate_manifests() -> ManifestRows:
    affix_rows = parse_affix_rows()
    trait_rows = parse_trait_rows()
    combatant_rows = parse_combatant_rows()
    enemy_rows = parse_enemy_rows()
    stage_rows = parse_stage_rows()
    homestead_rows = parse_homestead_node_rows()
    item_base_rows = parse_item_base_rows()
    talent_rows = parse_talent_rows()
    ability_tiers = collect_ability_tiers()
    ability_symbols = set(ability_tiers)
    combatant_ids = [row.id for row in combatant_rows]

    validate_affix_rows(affix_rows)
    validate_trait_rows(trait_rows)
    validate_talent_rows(talent_rows, combatant_ids)
    validate_combatant_rows(combatant_rows, ability_symbols, ability_tiers)
    validate_enemy_rows(
        enemy_rows,
        ability_symbols,
        set(combatant_ids),
        {row.id for row in trait_rows},
    )
    validate_stage_rows(
        stage_rows,
        enemy_ids={row.id for row in enemy_rows},
        mystery_event_ids=collect_mystery_event_ids(),
        recruit_event_ids=collect_recruit_event_ids(),
        art_ids=collect_art_ids(),
    )
    validate_homestead_node_rows(homestead_rows)
    validate_item_base_rows(item_base_rows)
    validate_affix_reachability(affix_rows, item_base_rows)
    return ManifestRows(
        affixes=affix_rows, traits=trait_rows, stages=stage_rows, combatants=combatant_rows,
        enemies=enemy_rows, homestead=homestead_rows, item_bases=item_base_rows, talents=talent_rows,
    )


def main() -> int:
    if len(sys.argv) > 2:
        raise SystemExit("Usage: content_codegen.py [validate|shorthand]")
    command = sys.argv[1] if len(sys.argv) > 1 else "all"
    if command not in {"all", "validate", "shorthand"}:
        raise SystemExit(f"Unknown command: {command}. Usage: content_codegen.py [validate|shorthand]")
    if command == "validate":
        print(f"Validated {validate_manifests().summary()}")
        return 0
    if command == "shorthand":
        generate_ability_shorthand()
        generate_ability_inventory()
        print("Generated AbilityShorthand.generated.swift and AbilityInventory.generated.tsv")
        return 0

    rows = validate_manifests()
    generate_affix_catalog(rows.affixes)
    generate_traits_catalog(rows.traits)
    generate_chapters_catalog(rows.stages)
    generate_stages_index()
    generate_roster_catalog(rows.combatants)
    generate_enemies_catalog(rows.enemies)
    generate_homestead_catalog(rows.homestead)
    generate_item_bases_catalog(rows.item_bases)
    generate_encounter_art_catalog(rows.stages)
    generate_modifiers()
    generate_trigger_families()
    generate_trigger_root()
    generate_affix_rolling(_trigger_families())
    generate_talent_catalog(rows.talents, [row.id for row in rows.combatants])
    generate_ability_shorthand()
    generate_ability_inventory()
    print(f"Generated {rows.summary()}, and {len(_trigger_families())} trigger families")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
