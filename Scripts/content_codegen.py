#!/usr/bin/env python3
"""Coordinate content validation and generation; domain owners live in internal/content."""

from __future__ import annotations

import sys

from internal.content.modifier_schema import generate_modifiers

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


def validate_manifests() -> tuple[
    list[AffixRow],
    list[TraitRow],
    list[StageRow],
    list[CombatantRow],
    list[EnemyRow],
    list[HomesteadNodeRow],
    list[ItemBaseRow],
    list[TalentRow],
]:
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
    return (
        affix_rows,
        trait_rows,
        stage_rows,
        combatant_rows,
        enemy_rows,
        homestead_rows,
        item_base_rows,
        talent_rows,
    )


def main() -> int:
    if len(sys.argv) > 2:
        raise SystemExit("Usage: content_codegen.py [validate|shorthand]")
    command = sys.argv[1] if len(sys.argv) > 1 else "all"
    if command not in {"all", "validate", "shorthand"}:
        raise SystemExit(f"Unknown command: {command}. Usage: content_codegen.py [validate|shorthand]")
    if command == "validate":
        (
            affix_rows,
            trait_rows,
            stage_rows,
            combatant_rows,
            enemy_rows,
            homestead_rows,
            item_base_rows,
            talent_rows,
        ) = validate_manifests()
        ability_count = len(collect_ability_symbols())
        print(
            f"Validated {len(affix_rows)} affixes, "
            f"{len(trait_rows)} traits, "
            f"{ability_count} abilities, "
            f"{len(stage_rows)} stages, "
            f"{len(combatant_rows)} combatants, "
            f"{len(enemy_rows)} enemies, "
            f"{len(homestead_rows)} homestead tiers, "
            f"{len(item_base_rows)} item bases, and "
            f"{len(talent_rows)} talents"
        )
        return 0
    if command == "shorthand":
        generate_ability_shorthand()
        generate_ability_inventory()
        print("Generated AbilityShorthand.generated.swift and AbilityInventory.generated.tsv")
        return 0

    (
        affix_rows,
        trait_rows,
        stage_rows,
        combatant_rows,
        enemy_rows,
        homestead_rows,
        item_base_rows,
        talent_rows,
    ) = validate_manifests()
    generate_affix_catalog(affix_rows)
    generate_traits_catalog(trait_rows)
    generate_chapters_catalog(stage_rows)
    generate_stages_index()
    generate_roster_catalog(combatant_rows)
    generate_enemies_catalog(enemy_rows)
    generate_homestead_catalog(homestead_rows)
    generate_item_bases_catalog(item_base_rows)
    generate_encounter_art_catalog(stage_rows)
    generate_modifiers()
    generate_trigger_families()
    generate_trigger_root()
    generate_talent_catalog(talent_rows, [row.id for row in combatant_rows])
    generate_ability_shorthand()
    generate_ability_inventory()
    ability_count = len(collect_ability_symbols())
    trigger_family_count = len(_trigger_families())
    print(
        f"Generated {len(affix_rows)} affixes, "
        f"{len(trait_rows)} traits, "
        f"{ability_count} abilities, "
        f"{len(stage_rows)} stages, "
        f"{len(combatant_rows)} combatants, "
        f"{len(enemy_rows)} enemies, "
        f"{len(homestead_rows)} homestead tiers, "
        f"{len(item_base_rows)} item bases, "
        f"{len(talent_rows)} talents, and "
        f"{trigger_family_count} trigger families"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
