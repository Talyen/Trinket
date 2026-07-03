#!/usr/bin/env python3
"""Generate Trinket content catalogs from ContentManifest TSV files."""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_DIR = ROOT / "ContentManifest"
GENERATED_DIR = ROOT / "Trinket" / "Generated"
CONTENT_DIR = ROOT / "Trinket" / "Content"

TIER_ENUM = {
    "basic": "AbilityCatalogBasicGenerated",
    "skill": "AbilityCatalogSkillGenerated",
    "ultimate": "AbilityCatalogUltimateGenerated",
}

TIER_SOURCE = {
    "basic": CONTENT_DIR / "AbilityCatalogBasic.swift",
    "skill": CONTENT_DIR / "AbilityCatalogSkill.swift",
    "ultimate": CONTENT_DIR / "AbilityCatalogUltimate.swift",
}


@dataclass
class AffixRow:
    id: str
    title: str
    slot: str
    keywords: str
    weight: str
    basic_description: str
    astral_description: str
    basic_modifiers: str
    astral_modifiers: str


@dataclass
class AbilityRow:
    pattern: str
    symbol: str
    id: str
    name: str
    tier: str
    amount: str = ""
    keyword: str = ""
    description: str = ""
    effects: str = ""
    damage_components: str = ""
    extras: str = ""


def read_tsv(path: Path) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in path.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        rows.append(line.split("\t"))
    return rows


def parse_affix_rows() -> list[AffixRow]:
    path = MANIFEST_DIR / "affixes.tsv"
    lines = read_tsv(path)
    header = lines[0]
    expected = [
        "id",
        "title",
        "slot",
        "keywords",
        "weight",
        "basic_description",
        "astral_description",
        "basic_modifiers",
        "astral_modifiers",
    ]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    return [AffixRow(*row) for row in lines[1:]]


def parse_ability_rows() -> list[AbilityRow]:
    path = MANIFEST_DIR / "abilities.tsv"
    lines = read_tsv(path)
    header = lines[0]
    expected = [
        "pattern",
        "symbol",
        "id",
        "name",
        "tier",
        "amount",
        "keyword",
        "description",
        "effects",
        "damage_components",
        "extras",
    ]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    rows: list[AbilityRow] = []
    for raw in lines[1:]:
        padded = raw + [""] * (len(expected) - len(raw))
        rows.append(AbilityRow(*padded[: len(expected)]))
    return rows


def swift_escape(value: str) -> str:
    value = value.replace("\\n", "\n")
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def parse_keywords(raw: str) -> str:
    if not raw:
        return "[]"
    parts = [part.strip() for part in raw.split(",") if part.strip()]
    return "[" + ", ".join(f".{part}" for part in parts) + "]"


def parse_modifier_tokens(raw: str) -> list[str]:
    if not raw:
        return []
    return [part.strip() for part in raw.split("|") if part.strip()]


def modifier_token_to_swift(token: str) -> str:
    if token.startswith("strength:"):
        return f".strength({token.split(':', 1)[1]})"
    if token.startswith("agility:"):
        return f".agility({token.split(':', 1)[1]})"
    if token.startswith("toughness:"):
        return f".toughness({token.split(':', 1)[1]})"
    if token.startswith("intellect:"):
        return f".intellect({token.split(':', 1)[1]})"
    if token.startswith("wisdom:"):
        return f".wisdom({token.split(':', 1)[1]})"
    if token.startswith("maximum_health:"):
        return f".maximumHealth({token.split(':', 1)[1]})"
    if token.startswith("damage_dealt:"):
        _, keyword, amount = token.split(":", 2)
        return f".damageDealt(.{keyword}, {amount})"
    if token.startswith("health_restored:"):
        return f".healthRestored({token.split(':', 1)[1]})"
    if token.startswith("leech_granted_percent:"):
        return f".leechGrantedPercent({token.split(':', 1)[1]})"
    if token.startswith("leech_healing:"):
        return f".leechHealing({token.split(':', 1)[1]})"
    if token.startswith("gold_gained:"):
        return f".goldGained({token.split(':', 1)[1]})"
    if token.startswith("block_granted:"):
        return f".blockGranted({token.split(':', 1)[1]})"
    if token.startswith("armor_granted_percent:"):
        return f".armorGrantedPercent({token.split(':', 1)[1]})"
    if token.startswith("block_duration:"):
        return f".blockDuration({token.split(':', 1)[1]})"
    if token.startswith("armor_duration:"):
        return f".armorDuration({token.split(':', 1)[1]})"
    if token.startswith("bleed_duration:"):
        return f".bleedDuration({token.split(':', 1)[1]})"
    if token.startswith("damage_taken_percent:"):
        _, keyword, amount = token.split(":", 2)
        return f".damageTakenPercent(.{keyword}, {amount})"
    raise ValueError(f"Unknown modifier token: {token}")


def modifiers_swift(raw: str) -> str:
    mods = [modifier_token_to_swift(token) for token in parse_modifier_tokens(raw)]
    return "[" + ", ".join(mods) + "]"


def parse_effect_token(token: str) -> str:
    target = None
    if "@" in token:
        token, target_name = token.split("@", 1)
    else:
        target_name = None

    if token == "standard_leech_buff":
        effect = ".standardLeechBuff"
    elif token == "cleanse_random":
        effect = ".cleanseRandom"
    elif token == "purge":
        effect = ".purge(nil)"
    elif token == "cleanse":
        effect = ".cleanse(nil)"
    elif token.startswith("cleanse:"):
        effect = f".cleanse(.{token.split(':', 1)[1]})"
    elif token.startswith("burn:"):
        effect = f".burn({token.split(':', 1)[1]})"
    elif token.startswith("poison:"):
        effect = f".poison({token.split(':', 1)[1]})"
    elif token.startswith("bleed:"):
        effect = f".bleed({token.split(':', 1)[1]})"
    elif token.startswith("shield:"):
        _, kind, amount, duration = token.split(":", 3)
        effect = f".shield(.{kind}, {amount}, {duration})"
    elif token.startswith("mitigation:"):
        _, kind, amount, duration = token.split(":", 3)
        effect = f".mitigation(.{kind}, {amount}, {duration})"
    elif token.startswith("instant_heal:"):
        _, kind, amount = token.split(":", 2)
        effect = f".instantHeal(.{kind}, {amount})"
    elif token.startswith("resource_gain:"):
        _, kind, amount = token.split(":", 2)
        effect = f".resourceGain(.{kind}, {amount})"
    elif token.startswith("halve_mitigation:"):
        effect = f".halveMitigation(.{token.split(':', 1)[1]})"
    else:
        raise ValueError(f"Unknown effect token: {token}")

    if target_name:
        return f"TargetedEffect({effect}, target: .{target_name})"
    return f"TargetedEffect({effect})"


def targeted_effects_swift(raw: str) -> list[str]:
    if not raw:
        return []
    return [parse_effect_token(token.strip()) for token in raw.split("|") if token.strip()]


def damage_components_swift(raw: str) -> list[str]:
    if not raw:
        return []
    components: list[str] = []
    for token in raw.split("|"):
        token = token.strip()
        if not token:
            continue
        parts = token.split(":")
        if len(parts) == 2:
            amount, keyword = parts
            target = ".abilityTarget"
        elif len(parts) == 3:
            amount, keyword, target_name = parts
            target = f".{target_name}"
        else:
            raise ValueError(f"Invalid damage component token: {token}")
        if target == ".abilityTarget":
            components.append(f"DamageComponent({amount}, keyword: .{keyword})")
        else:
            components.append(
                f"DamageComponent({amount}, keyword: .{keyword}, target: {target})"
            )
    return components


def optional_description(description: str) -> str:
    if not description:
        return ""
    escaped = swift_escape(description)
    return f',\n        description: "{escaped}"'


def render_direct_hit(row: AbilityRow) -> str:
    amount = row.amount or "0"
    keyword = row.keyword or "physical"
    extras = targeted_effects_swift(row.extras)
    description = optional_description(row.description)
    if extras:
        extras_arg = ", ".join(extras)
        return (
            f"    static let {row.symbol} = AbilityBuilder.directHit(\n"
            f'        id: "{row.id}", name: "{swift_escape(row.name)}", tier: .{row.tier},\n'
            f"        amount: {amount}, keyword: .{keyword}{description},\n"
            f"        extras: [{extras_arg}]\n"
            f"    )"
        )
    return (
        f"    static let {row.symbol} = AbilityBuilder.directHit(\n"
        f'        id: "{row.id}", name: "{swift_escape(row.name)}", tier: .{row.tier},\n'
        f"        amount: {amount}, keyword: .{keyword}{description}\n"
        f"    )"
    )


def effect_swift(token: str) -> str:
    parsed = parse_effect_token(token.strip())
    return parsed.removeprefix("TargetedEffect(").removesuffix(")")


def render_buff_only(row: AbilityRow) -> str:
    effects = ", ".join(effect_swift(token) for token in row.effects.split("|") if token.strip())
    description = optional_description(row.description)
    return (
        f"    static let {row.symbol} = AbilityBuilder.buffOnly(\n"
        f'        id: "{row.id}", name: "{swift_escape(row.name)}", tier: .{row.tier},\n'
        f"        effects: [{effects}]{description}\n"
        f"    )"
    )


def render_multi_damage(row: AbilityRow) -> str:
    damage = ", ".join(damage_components_swift(row.damage_components))
    effects = ", ".join(targeted_effects_swift(row.effects))
    description = optional_description(row.description)
    effects_clause = f",\n        effects: [{effects}]" if effects else ""
    return (
        f"    static let {row.symbol} = AbilityBuilder.multiDamage(\n"
        f'        id: "{row.id}", name: "{swift_escape(row.name)}", tier: .{row.tier},\n'
        f"        damageComponents: [{damage}]{effects_clause}{description}\n"
        f"    )"
    )


def render_ability(row: AbilityRow) -> str:
    if row.pattern == "direct_hit":
        return render_direct_hit(row)
    if row.pattern == "buff_only":
        return render_buff_only(row)
    if row.pattern == "multi_damage":
        return render_multi_damage(row)
    raise ValueError(f"Unsupported ability pattern '{row.pattern}' for {row.id}")


def write_generated_file(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "// Generated by Scripts/generate-content-catalogs.sh — do not edit.\n"
        "import Foundation\n\n"
        f"{body}\n"
    )


def generate_affix_catalog(rows: list[AffixRow]) -> None:
    seen: set[str] = set()
    for row in rows:
        if row.id in seen:
            raise ValueError(f"Duplicate affix id: {row.id}")
        seen.add(row.id)

    entries: list[str] = []
    for row in rows:
        entries.append(
            "        ItemAffixCatalogSupport.affix(\n"
            f'            id: "{row.id}",\n'
            f'            title: "{swift_escape(row.title)}",\n'
            f"            slot: .{row.slot},\n"
            f"            keywords: {parse_keywords(row.keywords)},\n"
            f"            weight: {row.weight},\n"
            f'            basic: ItemAffixPower(description: "{swift_escape(row.basic_description)}", modifiers: {modifiers_swift(row.basic_modifiers)}),\n'
            f'            astral: ItemAffixPower(description: "{swift_escape(row.astral_description)}", modifiers: {modifiers_swift(row.astral_modifiers)})\n'
            "        )"
        )

    body = (
        "enum ItemAffixCatalogGenerated {\n"
        "    static let definitions: [ItemAffixDefinition] = [\n"
        + ",\n".join(entries)
        + ",\n    ]\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "ItemAffixCatalog.generated.swift", body)


def generate_ability_tier_catalog(tier: str, rows: list[AbilityRow]) -> None:
    enum_name = TIER_ENUM[tier]
    tier_rows = [row for row in rows if row.tier == tier]
    seen: set[str] = set()
    for row in tier_rows:
        if row.symbol in seen:
            raise ValueError(f"Duplicate ability symbol in {tier}: {row.symbol}")
        seen.add(row.symbol)

    definitions = [render_ability(row) for row in tier_rows]
    all_entries = ",\n        ".join(row.symbol for row in tier_rows)
    body = (
        f"enum {enum_name} {{\n"
        + ("\n\n".join(definitions) if definitions else "")
        + ("\n\n" if definitions else "")
        + "    static let all: [Ability] = [\n"
        + (f"        {all_entries}\n" if tier_rows else "")
        + "    ]\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / f"AbilityCatalog{tier.capitalize()}.generated.swift", body)


def parse_custom_ability_symbols(path: Path) -> list[tuple[str, str]]:
    text = path.read_text()
    return [(match.group(1), path.stem) for match in re.finditer(r"static let (\w+) = Ability\(", text)]


def parse_generated_ability_symbols(path: Path) -> list[tuple[str, str]]:
    text = path.read_text()
    enum_match = re.search(r"enum (\w+)", text)
    if not enum_match:
        return []
    enum_name = enum_match.group(1)
    return [(match.group(1), enum_name) for match in re.finditer(r"static let (\w+) = AbilityBuilder", text)]


def generate_ability_shorthand() -> None:
    entries: list[tuple[str, str]] = []
    for tier in ("Basic", "Skill", "Ultimate"):
        hand_path = CONTENT_DIR / f"AbilityCatalog{tier}.swift"
        generated_path = GENERATED_DIR / f"AbilityCatalog{tier}.generated.swift"
        for symbol, enum_name in parse_custom_ability_symbols(hand_path):
            entries.append((symbol, f"AbilityCatalog{tier}.{symbol}"))
        if generated_path.exists():
            for symbol, enum_name in parse_generated_ability_symbols(generated_path):
                entries.append((symbol, f"{enum_name}.{symbol}"))

    entries.sort(key=lambda item: item[0])
    lines = [f"    static let {symbol} = {target}" for symbol, target in entries]
    body = "extension Ability {\n" + "\n".join(lines) + "\n}\n"
    write_generated_file(GENERATED_DIR / "AbilityShorthand.generated.swift", body)


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else "all"
    if command == "shorthand":
        generate_ability_shorthand()
        print("Generated AbilityShorthand.generated.swift")
        return 0

    affix_rows = parse_affix_rows()
    ability_rows = parse_ability_rows()
    generate_affix_catalog(affix_rows)
    for tier in ("basic", "skill", "ultimate"):
        generate_ability_tier_catalog(tier, ability_rows)
    generate_ability_shorthand()
    print(
        f"Generated {len(affix_rows)} affixes and "
        f"{len(ability_rows)} manifest abilities"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
