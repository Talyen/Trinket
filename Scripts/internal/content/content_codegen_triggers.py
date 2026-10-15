#!/usr/bin/env python3
"""Trigger-family DSL validation and Swift generation."""

from __future__ import annotations

from pathlib import Path
import functools
import re

from .content_codegen_modifiers import (
    VALID_KEYWORDS,
    modifiers_swift,
    parse_modifier_tokens,
    parse_typed_bool,
    parse_typed_double,
    parse_typed_int,
)
from internal.cli import read_json
from internal.content.common import GENERATED_DIR, write_if_changed


TRIGGER_FAMILY_SCHEMA = Path(__file__).resolve().parent / "trigger_families" / "index.json"

# Type -> neutral default, conventional merge, permitted merges.
TRIGGER_TYPES = {
    "Int": ("0", "add", {"add", "max", "mul", "add_excess"}),
    "Double": ("0", "add", {"add", "max", "mul", "add_excess"}),
    "Bool": ("false", "or", {"or"}),
    "Keyword?": ("nil", "coalesce", {"coalesce"}),
    "[Int]": ("[]", "union", {"union"}),
}


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
    for family in families:
        if not all(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", family[key]) for key in ("family", "file_stem")):
            raise ValueError("Trigger family and output stem must be Swift identifiers")
        for field in family["fields"]:
            if set(field) - {"name", "type", "default", "merge", "affix_roll"}:
                raise ValueError(f"Unknown trigger field attributes: {field}")
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", field["name"]):
                raise ValueError(f"Invalid trigger field name {field['name']!r}")
            if field["type"] not in TRIGGER_TYPES:
                raise ValueError(f"Unknown trigger type {field['type']!r} for {field['name']!r}")
            default, merge, allowed_merges = TRIGGER_TYPES[field["type"]]
            field.setdefault("default", default)
            field.setdefault("merge", merge)
            if field["merge"] not in allowed_merges:
                raise ValueError(f"Invalid merge op {field['merge']!r} for {field['type']} field {field['name']!r}")
            if field["type"] == "Keyword?" and field["default"] == "nil":
                continue
            normalized = _validate_trigger_value(field["name"], field["type"], field["default"], family["family"])
            if normalized != field["default"]:
                raise ValueError(f"Trigger default for {field['name']!r} must use a Swift literal")
    from internal.content.affix_rolling import rolling_policies
    rolling_policies(families)
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
    "poison_attack_leech": "poisonAttackLeech",
    "victory_gold_coin": "victoryGoldCoin",
}


def _apply_simple_trigger(token: str, values: dict[str, str]) -> bool:
    name, separator, value = token.partition(":")
    if separator and name in _TRIGGER_SIMPLE_MAP:
        values[_TRIGGER_SIMPLE_MAP[name]] = value
        return True
    if name in _FLAG_TRIGGERS:
        remainder = value.strip()
        # Bare/empty flags mean true; typed validation owns all other values.
        values[_FLAG_TRIGGERS[name]] = "true" if not remainder or remainder.lower() in ("true", "1") else remainder
        return True
    return False


_BESPOKE_TRIGGER_SPECS = {
    "damage_below_health_percent": (
        "threshold[:keyword]:bonus",
        ("damageBelowHealthPercentThreshold", "damageBelowHealthPercentBonus"),
        ("damageBelowHealthPercentThreshold", "damageBelowHealthPercentKeyword", "damageBelowHealthPercentBonus"),
    ),
    "once_below_health_percent_heal": (
        "threshold:amount", ("onceBelowHealthPercentThreshold", "onceBelowHealthPercentHeal"),
    ),
    "dodge_chance_below_health_percent": (
        "threshold:bonus", ("dodgeChanceBelowHealthPercentThreshold", "dodgeChanceBelowHealthPercentBonus"),
    ),
    "turn_random_damage_all_enemies": (
        "keyword:keyword:amount",
        ("turnRandomDamageAllEnemiesKeywordA", "turnRandomDamageAllEnemiesKeywordB", "turnRandomDamageAllEnemiesAmount"),
    ),
    "cards_played_mana": (
        "threshold:amount", ("cardsPlayedManaThreshold", "cardsPlayedManaFlat"),
    ),
}


def _apply_bespoke_trigger(token: str, values: dict[str, str], field_types: dict[str, str]) -> bool:
    prefix, separator, value = token.partition(":")
    if not separator or prefix not in _BESPOKE_TRIGGER_SPECS:
        return False
    usage, *shapes = _BESPOKE_TRIGGER_SPECS[prefix]
    args = value.split(":")
    fields = next((shape for shape in shapes if len(shape) == len(args)), None)
    if fields is None:
        raise ValueError(f"{prefix} expects {usage}, got {token!r}")
    for field, arg in zip(fields, args):
        # Field types come from the schema; normal typed validation checks keywords.
        values[field] = f".{arg}" if field_types[field] == "Keyword?" else arg
    return True


def _trigger_field_types() -> dict[str, str]:
    return {
        field["name"]: field["type"]
        for family in _trigger_families()
        for field in family["fields"]
    }


def _validate_trigger_value(field: str, field_type: str | None, raw_value: str, row_id: str) -> str:
    if field_type is None:
        raise ValueError(f"Unknown trigger field: {field}")
    value = raw_value.strip()
    scalar_parsers = {
        "Int": parse_typed_int,
        "Double": parse_typed_double,
        "Bool": parse_typed_bool,
    }
    if field_type in scalar_parsers:
        parsed = scalar_parsers[field_type](value, f"{field} for {row_id}")
        return ("true" if parsed else "false") if field_type == "Bool" else raw_value
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
        parts = inner.split(",") if inner.strip() else []
        if parts and not parts[-1].strip():
            parts.pop()  # Swift permits one trailing comma.
        for part in parts:
            parse_typed_int(part, f"{field} for {row_id}")
    return raw_value


def parse_trigger_values(raw: str, row_id: str = "") -> dict[str, str]:
    field_types = _trigger_field_types()
    label = row_id or "triggers"
    seen_fields: dict[str, str] = {}
    values: dict[str, str] = {}
    for token in parse_modifier_tokens(raw):
        resolved: dict[str, str] = {}
        if not (_apply_simple_trigger(token, resolved) or _apply_bespoke_trigger(token, resolved, field_types)):
            field, separator, value = token.partition(":")
            if not separator:
                raise ValueError(f"Unknown trigger token: {token}")
            if "_" in field:
                parts = field.split("_")
                if any(not part for part in parts):
                    raise ValueError(f"Malformed trigger token {token!r}: empty snake_case segment")
                field = parts[0] + "".join(part.title() for part in parts[1:])
            if field not in field_types:
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
        values[field] = _validate_trigger_value(field, field_types.get(field), raw_value, label)
    return values


def triggers_swift(raw: str, row_id: str = "", *, indent: str = "") -> str:
    values = parse_trigger_values(raw, row_id)
    parts = []
    for family in _trigger_families():
        fields = {field["name"] for field in family["fields"]}
        assignments = [f"$0.{label} = {value}" for label, value in values.items() if label in fields]
        if not assignments:
            continue
        if len(assignments) == 1:
            body = "{ " + assignments[0] + " }"
        else:
            body = "{\n" + "\n".join(indent + "        " + line for line in assignments) + "\n" + indent + "    }"
        parts.append(f"{family['family']}: {family['file_stem']} {body}")
    if not parts:
        return "CombatTraitTriggers()"
    if len(parts) == 1 and "\n" not in parts[0]:
        return "CombatTraitTriggers(" + parts[0] + ")"
    return "CombatTraitTriggers(\n" + ",\n".join(indent + "    " + part for part in parts) + "\n" + indent + ")"


def power_arguments_swift(modifiers: str, triggers: str, *, indent: str) -> str:
    """Let Swift's power initializers own the defaults for empty DSL columns."""
    return "".join(
        f",\n{indent}{label}: {render(raw)}"
        for label, raw, render in (
            ("modifiers", modifiers, modifiers_swift),
            ("triggers", triggers, lambda raw: triggers_swift(raw, indent=indent)),
        )
        if raw.strip()
    )


def generate_trigger_families() -> None:
    families = _trigger_families()
    for family in families:
        type_name = family["file_stem"]
        family_id = family["family"]
        fields = family["fields"]
        props = "\n".join(
            f"    public var {f['name']}: {f['type']} = {f['default']}" for f in fields
        )
        text = f"""// Generated by Scripts/content_codegen.py — do not edit.
import TrinketCore

/// The `{family_id}` trigger family of `CombatTraitTriggers`.
public struct {type_name}: Equatable, Hashable, Sendable {{
{props}

    public init(_ configure: (inout Self) -> Void = {{ _ in }}) {{
        configure(&self)
    }}
}}
"""
        out = GENERATED_DIR / f"{type_name}.generated.swift"
        write_if_changed(out, text)


def generate_trigger_root() -> None:
    families = _trigger_families()
    pairs = [(family["family"], family["file_stem"]) for family in families]
    field_decls = "\n".join(f"        var {fid} = {tname}()" for fid, tname in pairs)
    init_params = ",\n".join(
        f"        {fid}: {tname} = {tname}()" for fid, tname in pairs
    )
    init_assigns = ",\n".join(f"            {fid}: {fid}" for fid, _ in pairs)
    subscripts = "\n\n".join(
        f"""    public subscript<T>(dynamicMember keyPath: WritableKeyPath<{tname}, T>) -> T {{
        _read {{ yield storage.value.{fid}[keyPath: keyPath] }}
        _modify {{ yield &fields.{fid}[keyPath: keyPath] }}
    }}"""
        for fid, tname in pairs
    )
    field_cases = "\n".join(
        f"    case {field['name']}" for family in families for field in family["fields"]
    )
    descriptors = "\n".join(
        f"        .init(\\.{family['family']}.{field['name']}, .{field['name']}, default: {field['default']}, merging: .{field['merge'].replace('add_excess', 'addExcess')}),"
        for family in families for field in family["fields"]
    )
    text = f"""// Generated by Scripts/content_codegen.py — do not edit.
import Foundation
import TrinketCore

/// Schema-owned identity shared by combat provenance and affix policy.
/// Raw values retain the flat Codable field names; gameplay uses typed cases.
public enum CombatTriggerField: String, CodingKey, CaseIterable, Sendable {{
{field_cases}
}}

@dynamicMemberLookup
public struct CombatTraitTriggers: Codable, @unchecked Sendable, Equatable, Hashable {{
    struct Fields: Equatable, Hashable, Sendable {{
{field_decls}

        mutating func merge(_ other: Self) {{
            for field in CombatTraitTriggers.schema {{
                field.merge(other, &self)
            }}
        }}
    }}

    private static let schema: [TriggerField<Fields>] = [
{descriptors}
    ]

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

    public var populatedFields: [CombatTriggerField] {{
        let defaults = Fields()
        return Self.schema.compactMap {{ $0.differs(fields, defaults) ? $0.field : nil }}
    }}

    public mutating func merge(_ other: Self) {{
        fields.merge(other.fields)
    }}

    public func merged(with other: Self) -> Self {{
        var copy = self
        copy.merge(other)
        return copy
    }}

    public init(from decoder: Decoder) throws {{
        let values = try decoder.container(keyedBy: CombatTriggerField.self)
        var decoded = Fields()
        for field in Self.schema {{
            try field.decode(values, &decoded)
        }}
        storage = Storage(decoded)
    }}

    public func encode(to encoder: Encoder) throws {{
        var container = encoder.container(keyedBy: CombatTriggerField.self)
        for field in Self.schema {{
            try field.encode(fields, &container)
        }}
    }}
}}
"""
    out = GENERATED_DIR / "CombatTraitTriggers.generated.swift"
    write_if_changed(out, text)
