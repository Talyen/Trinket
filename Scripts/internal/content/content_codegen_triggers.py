#!/usr/bin/env python3
"""Trigger-family DSL validation and Swift generation."""

from __future__ import annotations

from pathlib import Path
import functools
import re

from .content_codegen_modifiers import (
    VALID_KEYWORDS,
    parse_modifier_tokens,
    parse_typed_bool,
    parse_typed_double,
    parse_typed_int,
)
from internal.cli import read_json
from internal.content.common import GENERATED_DIR, write_if_changed


TRIGGER_FAMILY_SCHEMA = Path(__file__).resolve().parent / "trigger_families" / "index.json"


@functools.cache
def _trigger_families() -> list:
    payload = read_json(TRIGGER_FAMILY_SCHEMA)
    names = payload["families"]
    if len(names) != len(set(names)) or any(Path(name).name != name or not name.endswith(".json") or name == "index.json" for name in names):
        raise ValueError("Trigger family index must contain unique JSON basenames")
    families = [read_json(TRIGGER_FAMILY_SCHEMA.parent / name) for name in names]
    family_names = [family["family"] for family in families]
    stems = [family["file_stem"] for family in families]
    fields = [field["name"] for family in families for field in family["fields"]]
    if any(len(values) != len(set(values)) for values in (family_names, stems, fields)):
        raise ValueError("Duplicate trigger family, output stem, or field")
    valid_types = {"Int", "Bool", "Double", "Keyword?", "[Int]"}
    valid_merges = {"add", "or", "max", "mul", "add_excess", "coalesce", "union"}
    for family in families:
        for field in family["fields"]:
            if field["type"] not in valid_types:
                raise ValueError(f"Unknown trigger type {field['type']!r} for {field['name']!r}")
            if field["merge"] not in valid_merges:
                raise ValueError(f"Unknown merge op {field['merge']!r} for {field['name']!r}")
    return families


_TRIGGER_SIMPLE_MAP: dict[str, str] = {
    "on_cleanse_draw": "cleanseBonusDraw",
    "on_cleanse_self_heal": "cleanseSelfHeal",
    "on_cleanse_heal": "cleanseBonusHeal",
    "on_gain_gold_heal": "gainGoldBonusHealSelf",
    "dodge_chance_bonus": "dodgeChanceBonus",
    "passive_mitigation": "passiveMitigationFlat",
    "thorns_percent": "thornsPercent",
    "burn_decay_slow": "burnDecaySlowPercent",
    "on_bleed_apply_poison": "onBleedApplyPoison",
    "on_burn_apply_poison": "onBurnApplyPoison",
    "on_bleed_deal_burn_damage": "onBleedDealBurnDamage",
    "poison_decay_increase_chance": "poisonDecayIncreaseChance",
    "freeze_damage_while_burning": "freezeDamageWhileBurningBonus",
    "damage_while_target_frozen": "damageWhileTargetFrozenBonus",
    "damage_after_dodge": "damageAfterDodgeBonus",
    "on_block_broken_block": "blockBrokenBlockFlat",
    "companion_leech_share_percent": "companionLeechSharePercent",
    "block_on_deaths_door": "blockOnDeathsDoor",
    "on_spend_mana_block": "spendManaBlockFlat",
    "on_spend_mana_random_dot": "spendManaRandomDoTFlat",
    "on_holy_damage_block": "holyDamageBlockFlat",
    "on_stun_damage_block": "stunDamageBlockFlat",
    "on_holy_damage_cleanse": "holyDamageCleanseCount",
    "on_holy_damage_heal": "holyDamageHealFlat",
    "on_burn_damage_heal": "burnDamageHealFlat",
    "on_dodge_gold": "dodgeGoldFlat",
    "ignore_enemy_mitigation_percent": "ignoreEnemyMitigationPercent",
    "on_stun_deal_physical": "stunDealPhysicalFlat",
    "damage_while_target_stunned": "damageWhileTargetStunnedBonus",
    "on_enemy_stunned_apply_marked": "enemyStunnedApplyMarked",
    "on_dodge_block": "dodgeBlockFlat",
    "on_dodge_apply_poison": "dodgeApplyPoison",
    "on_holy_damage_purge": "holyDamagePurgeCount",
    "once_death_revive_health": "onceDeathReviveHealth",
    "once_death_revive_block": "onceDeathReviveBlock",
    "on_enemy_stunned_purge": "enemyStunnedPurgeCount",
    "on_critical_purge": "criticalPurgeCount",
    "on_critical_gold": "criticalGoldFlat",
    "on_critical_action_gold": "criticalActionGoldFlat",
    "on_leech_restore_mana": "leechRestoreManaFlat",
    "on_gain_mana_block": "gainManaBlockFlat",
    "on_defeat_enemy_gold": "defeatEnemyGoldFlat",
    "on_leech_gold": "leechGoldFlat",
    "on_dodge_heal": "dodgeHealFlat",
    "on_dodge_deal_stun": "dodgeDealStunFlat",
    "block_per_turn": "blockPerTurn",
    "leech_chance": "leechChancePercent",
    "on_hit_attacker_burn": "onHitAttackerBurn",
    "turn_freeze_all_enemies": "turnFreezeDamageAllEnemies",
    "on_holy_damage_poison": "holyDamagePoisonFlat",
    "draw_every_other_turn": "drawEveryOtherTurn",
    "draw_on_health_loss": "drawOnHealthLoss",
    "physical_stun_buildup_percent": "physicalStunBuildupPercent",
    "block_gain_thorns_percent": "blockGainThornsPercent",
    "draw_on_spend_mana": "drawOnSpendMana",
    "physical_damage_block_percent": "physicalDamageBlockPercent",
    "on_bleed_damage_gold": "bleedDamageGoldFlat",
    "gold_per_turn": "goldPerTurn",
    "health_restored_poison_percent": "healthRestoredPoisonPercent",
    "sundering_block_multiplier": "sunderingBlockMultiplier",
    "victory_gold_flat": "victoryGoldFlat",
    "health_per_turn": "healthPerTurn",
    "companion_cards_per_turn": "companionCardsPerTurn",
    "freeze_extra_action_skips": "freezeExtraActionSkips",
    "stunned_damage_multiplier": "stunnedDamageMultiplier",
    "critical_chance_bonus": "criticalChanceBonus",
}

_FLAG_TRIGGERS: dict[str, str] = {
    "on_enemy_stunned_purge_all": "enemyStunnedPurgeAll",
    "on_critical_purge_all": "criticalPurgeAll",
    "first_hit_double_damage": "firstHitDoubleDamage",
    "repeat_mana_empowerment": "repeatManaEmpowerment",
    "freeze_damage_leech": "freezeDamageLeech",
    "poison_damage_leech": "poisonDamageLeech",
    "victory_gold_coin": "victoryGoldCoin",
}


def _sorted_by_declining_length(mapping: dict[str, str]) -> list[tuple[str, str]]:
    """Single home for longest-prefix-first ordering; shadow pairs
    (foo vs foo_all) must route to the longer prefix."""
    return sorted(mapping.items(), key=lambda kv: -len(kv[0]))


_SORTED_SIMPLE_TRIGGERS = _sorted_by_declining_length(_TRIGGER_SIMPLE_MAP)
_SORTED_FLAG_TRIGGERS = _sorted_by_declining_length(_FLAG_TRIGGERS)


def _apply_simple_trigger(token: str, values: dict[str, str]) -> bool:
    for prefix, field in _SORTED_SIMPLE_TRIGGERS:
        if token.startswith(prefix + ":"):
            values[field] = token.split(":", 1)[1]
            return True
    for prefix, field in _SORTED_FLAG_TRIGGERS:
        if token == prefix or token.startswith(prefix + ":"):
            if ":" in token:
                remainder = token.split(":", 1)[1].strip()
                if not remainder:
                    values[field] = "true"
                else:
                    # Normalize true/1 (any case) to true; anything else
                    # flows to Bool validation for a clear error.
                    values[field] = "true" if remainder.lower() in ("true", "1") else remainder
            else:
                values[field] = "true"
            return True
    return False


_BESPOKE_TRIGGER_SPECS: dict[str, tuple[str, dict[int, tuple[tuple[str, bool], ...]]]] = {
    "damage_below_health_percent": (
        "threshold[:keyword]:bonus",
        {
            2: (
                ("damageBelowHealthPercentThreshold", False),
                ("damageBelowHealthPercentBonus", False),
            ),
            3: (
                ("damageBelowHealthPercentThreshold", False),
                ("damageBelowHealthPercentKeyword", True),
                ("damageBelowHealthPercentBonus", False),
            ),
        },
    ),
    "once_below_health_percent_heal": (
        "threshold:amount",
        {
            2: (
                ("onceBelowHealthPercentThreshold", False),
                ("onceBelowHealthPercentHeal", False),
            ),
        },
    ),
    "dodge_chance_below_health_percent": (
        "threshold:bonus",
        {
            2: (
                ("dodgeChanceBelowHealthPercentThreshold", False),
                ("dodgeChanceBelowHealthPercentBonus", False),
            ),
        },
    ),
    "turn_random_damage_all_enemies": (
        "keyword:keyword:amount",
        {
            3: (
                ("turnRandomDamageAllEnemiesKeywordA", True),
                ("turnRandomDamageAllEnemiesKeywordB", True),
                ("turnRandomDamageAllEnemiesAmount", False),
            ),
        },
    ),
    "cards_played_mana": (
        "threshold:amount",
        {
            2: (
                ("cardsPlayedManaThreshold", False),
                ("cardsPlayedManaFlat", False),
            ),
        },
    ),
}


def _apply_bespoke_trigger(token: str, values: dict[str, str]) -> bool:
    for prefix, (usage, arities) in sorted(_BESPOKE_TRIGGER_SPECS.items(), key=lambda kv: -len(kv[0])):
        if not token.startswith(prefix + ":"):
            continue
        args = token.split(":")[1:]
        if len(args) not in arities:
            raise ValueError(f"{prefix} expects {usage}, got {token!r}")
        for (field, is_keyword), arg in zip(arities[len(args)], args):
            if is_keyword:
                if arg not in VALID_KEYWORDS:
                    raise ValueError(f"Unknown keyword {arg!r} in trigger token {token!r}")
                values[field] = f".{arg}"
            else:
                values[field] = arg
        return True
    return False


@functools.cache
def _trigger_schema_info() -> tuple[dict[str, str], list[str], dict[str, str]]:
    families = _trigger_families()
    field_group = {
        field["name"]: family["family"]
        for family in families
        for field in family["fields"]
    }
    group_order = [family["family"] for family in families]
    family_types = {family["family"]: family["file_stem"] for family in families}
    return field_group, group_order, family_types


@functools.cache
def _trigger_field_types() -> dict[str, str]:
    return {
        field["name"]: field["type"]
        for family in _trigger_families()
        for field in family["fields"]
    }


def _validate_trigger_value(field: str, raw_value: str, row_id: str) -> None:
    field_type = _trigger_field_types().get(field)
    if field_type is None:
        raise ValueError(f"Unknown trigger field: {field}")
    value = raw_value.strip()
    scalar_parsers = {
        "Int": parse_typed_int,
        "Double": parse_typed_double,
        "Bool": parse_typed_bool,
    }
    if field_type in scalar_parsers:
        scalar_parsers[field_type](value, f"{field} for {row_id}")
        return
    if field_type == "Keyword?":
        if not value.startswith(".") or value[1:] not in VALID_KEYWORDS:
            raise ValueError(
                f"Trigger value for {field} for {row_id} must be a known keyword, "
                f"got {raw_value!r}"
            )
    elif field_type == "[Int]":
        inner = value[1:-1] if value.startswith("[") and value.endswith("]") else None
        if inner is None:
            raise ValueError(
                f"Trigger value for {field} for {row_id} must be an integer list like [1, 4], "
                f"got {raw_value!r}"
            )
        for part in inner.split(","):
            if not part.strip():
                continue
            try:
                int(part.strip())
            except ValueError as error:
                raise ValueError(
                    f"Trigger value for {field} for {row_id} must be an integer list, "
                    f"got {raw_value!r}"
                ) from error


def parse_trigger_values(raw: str, row_id: str = "") -> dict[str, str]:
    known_fields = set(_trigger_field_types())
    label = row_id or "triggers"
    seen_fields: dict[str, str] = {}
    values: dict[str, str] = {}
    for token in parse_modifier_tokens(raw):
        resolved: dict[str, str] = {}
        if not (_apply_simple_trigger(token, resolved) or _apply_bespoke_trigger(token, resolved)):
            field, separator, value = token.partition(":")
            if not separator:
                raise ValueError(f"Unknown trigger token: {token}")
            if "_" in field:
                parts = field.split("_")
                if any(not part for part in parts):
                    raise ValueError(f"Malformed trigger token {token!r}: empty snake_case segment")
                field = parts[0] + "".join(part.title() for part in parts[1:])
            if field not in known_fields:
                raise ValueError(f"Unknown trigger token: {token}")
            if re.search(r",[A-Za-z_][A-Za-z0-9_]*:", value):
                raise ValueError(f"Glued trigger token {token!r}; separate fields with |")
            resolved[field] = value
        for field in resolved:
            if field in seen_fields:
                raise ValueError(
                    f"Duplicate trigger field {field!r} for {label}: "
                    f"{token!r} repeats {seen_fields[field]!r}; merge into one token"
                )
            seen_fields[field] = token
        values.update(resolved)
    for field, raw_value in values.items():
        _validate_trigger_value(field, raw_value, label)
    return values


def triggers_swift(raw: str, row_id: str = "") -> str:
    field_group, group_order, family_types = _trigger_schema_info()
    values = parse_trigger_values(raw, row_id)
    grouped: dict[str, list[str]] = {g: [] for g in group_order}
    for label in values:
        try:
            grouped[field_group[label]].append(label)
        except KeyError as error:
            raise ValueError(f"Unknown trigger field: {label}") from error
    parts = []
    for g in group_order:
        fields = grouped[g]
        if not fields:
            continue
        gtype = family_types[g]
        inner = ", ".join(f"{label}: {values[label]}" for label in fields)
        parts.append(f"{g}: {gtype}({inner})")
    if not parts:
        return "CombatTraitTriggers()"
    return "CombatTraitTriggers(" + ", ".join(parts) + ")"


def generate_trigger_families() -> None:
    families = _trigger_families()
    merge_lines = {
        "add": lambda n: f"        {n} += other.{n}",
        "mul": lambda n: f"        {n} *= other.{n}",
        "add_excess": lambda n: f"        {n} += other.{n} - 1",
        "or": lambda n: f"        {n} = {n} || other.{n}",
        "max": lambda n: f"        {n} = max({n}, other.{n})",
        "coalesce": lambda n: f"        {n} = other.{n} ?? {n}",
        "union": lambda n: (
            f"        if !other.{n}.isEmpty {{\n"
            f"            {n} = {n}.isEmpty ? other.{n}.sorted() : Array(Set({n}).union(other.{n})).sorted()\n"
            "        }"
        ),
    }
    for family in families:
        type_name = family["file_stem"]
        family_id = family["family"]
        fields = family["fields"]
        props = "\n".join(
            f"    public var {f['name']}: {f['type']} = {f['default']}" for f in fields
        )
        init_params = ",\n".join(
            f"        {f['name']}: {f['type']} = {f['default']}" for f in fields
        )
        init_assigns = "\n".join(
            f"        self.{f['name']} = {f['name']}" for f in fields
        )
        merges = "\n".join(merge_lines[f["merge"]](f["name"]) for f in fields)
        decode_args = ",\n".join(
            "            {name}: values.decode({typ}.self, \"{name}\", default: {default})".format(
                name=f["name"], typ=f["type"], default=f["default"]
            )
            for f in fields
        )
        encodes = "\n".join(
            f'        try container.encodeNonDefault({f["name"]}, "{f["name"]}", default: {f["default"]})'
            for f in fields
        )
        field_names_literal = ", ".join(f'"{f["name"]}"' for f in fields)
        populated_checks = "\n".join(
            f'        if self.{f["name"]} != other.{f["name"]} {{ names.append("{f["name"]}") }}'
            for f in fields
        )
        text = f"""// Generated by Scripts/content_codegen.py — do not edit.
import Foundation
import TrinketCore

/// The `{family_id}` trigger family of `CombatTraitTriggers`.
public struct {type_name}: Equatable, Hashable, Sendable {{
{props}

    public init(
{init_params}
    ) {{
{init_assigns}
    }}

    /// All field names for this family — avoids `Mirror` reflection.
    public static let fieldNames: [String] = [{field_names_literal}]

    /// Field names where `self` differs from `other`.
    func populatedFieldNames(comparedTo other: Self) -> [String] {{
        var names: [String] = []
{populated_checks}
        return names
    }}
}}

extension {type_name} {{
    mutating func merge(_ other: Self) {{
{merges}
    }}
}}

extension {type_name} {{
    /// Decodes this family's flat trigger keys.
    init(from values: DefaultingTriggerDecoder) throws {{
        try self.init(
{decode_args}
        )
    }}

    func encode(to container: inout KeyedEncodingContainer<TriggerCodingKey>) throws {{
{encodes}
    }}
}}
"""
        out = GENERATED_DIR / f"{type_name}.generated.swift"
        write_if_changed(out, text)


def generate_trigger_root() -> None:
    families = _trigger_families()
    pairs = [(family["family"], family["file_stem"]) for family in families]
    field_decls = "\n".join(f"        var {fid}: {tname}" for fid, tname in pairs)
    default_inits = ",\n".join(
        f"            {fid}: {tname}()" for fid, tname in pairs
    )
    init_params = ",\n".join(
        f"        {fid}: {tname} = {tname}()" for fid, tname in pairs
    )
    init_assigns = ",\n".join(f"            {fid}: {fid}" for fid, _ in pairs)
    subscripts = "\n\n".join(
        f"""    public subscript<T>(dynamicMember keyPath: KeyPath<{tname}, T>) -> T {{
        _read {{ yield storage.value.{fid}[keyPath: keyPath] }}
    }}

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<{tname}, T>) -> T {{
        _read {{ yield storage.value.{fid}[keyPath: keyPath] }}
        set {{
            fields.{fid}[keyPath: keyPath] = newValue
        }}
    }}"""
        for fid, tname in pairs
    )
    all_names = "\n            + ".join(f"{tname}.fieldNames" for _, tname in pairs)
    populated = "\n            + ".join(
        f"fields.{fid}.populatedFieldNames(comparedTo: {tname}())"
        for fid, tname in pairs
    )
    merges = "\n".join(
        f"        fields.{fid}.merge(other.fields.{fid})" for fid, _ in pairs
    )
    decode_args = ",\n".join(
        f"            {fid}: {tname}(from: values)" for fid, tname in pairs
    )
    encodes = "\n".join(
        f"        try fields.{fid}.encode(to: &container)" for fid, _ in pairs
    )
    text = f"""// Generated by Scripts/content_codegen.py — do not edit.
import Foundation
import TrinketCore

@dynamicMemberLookup
public struct CombatTraitTriggers: Codable, @unchecked Sendable, Equatable, Hashable {{
    struct Fields: Equatable, Hashable, Sendable {{
{field_decls}
    }}

    private final class Storage {{
        var value: Fields

        init(_ value: Fields) {{
            self.value = value
        }}
    }}

    private var storage: Storage

    var fields: Fields {{
        _read {{ yield storage.value }}
        _modify {{
            if !isKnownUniquelyReferenced(&storage) {{
                storage = Storage(storage.value)
            }}
            yield &storage.value
        }}
    }}

    public init() {{
        storage = Storage(Fields(
{default_inits}
        ))
    }}

    public init(
{init_params}
    ) {{
        storage = Storage(Fields(
{init_assigns}
        ))
    }}

    public static func == (lhs: Self, rhs: Self) -> Bool {{
        lhs.fields == rhs.fields
    }}

    public func hash(into hasher: inout Hasher) {{
        hasher.combine(fields)
    }}

{subscripts}

    public static var allFieldNames: [String] {{
        {all_names}
    }}

    public var populatedFieldNames: [String] {{
        {populated}
    }}

    public mutating func merge(_ other: Self) {{
{merges}
    }}

    public func merged(with other: Self) -> Self {{
        var copy = self
        copy.merge(other)
        return copy
    }}

    public init(from decoder: Decoder) throws {{
        let values = try DefaultingTriggerDecoder(decoder)
        try self.init(
{decode_args}
        )
    }}

    public func encode(to encoder: Encoder) throws {{
        var container = encoder.container(keyedBy: TriggerCodingKey.self)
{encodes}
    }}
}}
"""
    out = GENERATED_DIR / "CombatTraitTriggers.generated.swift"
    write_if_changed(out, text)
