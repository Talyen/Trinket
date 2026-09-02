#!/usr/bin/env python3
"""Modifier-DSL and Swift publicize ownership for content codegen."""

from __future__ import annotations

import re

TOP_LEVEL = re.compile(r"^(?P<kind>enum|struct|class|actor|extension)\s+")
MEMBER = re.compile(
    r"^(?P<indent>\s{4})(?!(public |private |fileprivate |internal |open |case ))"
    r"(?P<body>(?:mutating )?(?:nonisolated )?(?:static )?(?:init|let|var|func|subscript)(?:\s|\())"
)
NESTED_TYPE = re.compile(
    r"^(?P<indent>\s{4})(?!(public |private |fileprivate |internal |open ))"
    r"(?P<body>(?:enum|struct|class|actor) )"
)


def parse_modifier_tokens(raw: str) -> list[str]:
    if not raw:
        return []
    return [part.strip() for part in raw.split("|") if part.strip()]


_MODIFIER_SIMPLE: dict[str, str] = {
    "maximum_health": ".maximumHealth",
    "health_restored": ".healthRestored",
    "leech_gained_percent": ".leechGainedPercent",
    "leech_healing": ".leechHealing",
    "gold_gained": ".goldGained",
    "gold_gained_percent": ".goldGainedPercent",
    "block_gained": ".blockGained",
    "bleed_duration": ".bleedDuration",
    "companion_damage_dealt": ".companionDamageDealt",
    "maximum_mana": ".maximumMana",
    "companion_bleed_damage_dealt": ".companionBleedDamageDealt",
    "poison_damage_dealt_percent": ".poisonDamageDealtPercent",
    "outgoing_damage_percent": ".outgoingDamagePercent",
    "incoming_damage_reduction_percent": ".incomingDamageReductionPercent",
    "dodge_chance_bonus": ".dodgeChanceBonus",
}


def modifier_token_to_swift(token: str) -> str:
    if ":" not in token:
        raise ValueError(f"Unknown modifier token: {token}")
    prefix, rest = token.split(":", 1)
    if prefix in _MODIFIER_SIMPLE:
        return f"{_MODIFIER_SIMPLE[prefix]}({rest})"
    if prefix == "damage_dealt":
        keyword, amount = rest.split(":", 1)
        return f".damageDealt(.{keyword}, {amount})"
    if prefix == "damage_taken_percent":
        keyword, amount = rest.split(":", 1)
        return f".damageTakenPercent(.{keyword}, {amount})"
    if prefix == "damage_taken_vulnerability":
        keyword, amount = rest.split(":", 1)
        return f".damageTakenVulnerability(.{keyword}, {amount})"
    raise ValueError(f"Unknown modifier token: {token}")


def modifiers_swift(raw: str) -> str:
    mods = [modifier_token_to_swift(token) for token in parse_modifier_tokens(raw)]
    return "[" + ", ".join(mods) + "]"


def publicize(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    depth = 0
    in_public_type = False

    for line in lines:
        if depth == 0:
            top = TOP_LEVEL.match(line)
            if top and not line.startswith("public "):
                if re.search(r"\b\w+Generated\b", line):
                    in_public_type = False
                elif top.group("kind") == "extension":
                    line = f"public {line}"
                    in_public_type = False
                else:
                    line = f"public {line}"
                    in_public_type = True
            else:
                in_public_type = False

        if in_public_type and depth == 1:
            match = MEMBER.match(line) or NESTED_TYPE.match(line)
            if match:
                rest = line.lstrip()
                line = f"{match.group('indent')}public {rest}"

        out.append(line)
        depth = max(0, depth + swift_brace_delta(line))

    return "\n".join(out) + "\n"


def swift_brace_delta(line: str) -> int:
    delta = 0
    in_string = False
    escaped = False
    index = 0
    while index < len(line):
        character = line[index]
        if in_string:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
        elif character == '"':
            in_string = True
        elif character == "/" and index + 1 < len(line) and line[index + 1] == "/":
            break
        elif character == "{":
            delta += 1
        elif character == "}":
            delta -= 1
        index += 1
    return delta
