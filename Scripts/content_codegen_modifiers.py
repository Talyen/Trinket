#!/usr/bin/env python3
"""Modifier-DSL ownership for content codegen."""

from __future__ import annotations

import math


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


_MODIFIER_INT_PREFIXES = frozenset(
    {
        "maximum_health",
        "health_restored",
        "leech_healing",
        "gold_gained",
        "block_gained",
        "bleed_duration",
        "companion_damage_dealt",
        "maximum_mana",
        "companion_bleed_damage_dealt",
        "damage_dealt",
    }
)

_MODIFIER_DOUBLE_PREFIXES = frozenset(
    {
        "leech_gained_percent",
        "gold_gained_percent",
        "poison_damage_dealt_percent",
        "outgoing_damage_percent",
        "incoming_damage_reduction_percent",
        "dodge_chance_bonus",
        "damage_taken_percent",
        "damage_taken_vulnerability",
    }
)

_MODIFIER_KEYWORD_PREFIXES = frozenset(
    {"damage_dealt", "damage_taken_percent", "damage_taken_vulnerability"}
)


VALID_KEYWORDS: frozenset[str] = frozenset(
    {
        "physical",
        "bleed",
        "burn",
        "freeze",
        "poison",
        "holy",
        "stun",
        "health",
        "block",
        "leech",
        "gold",
        "mana",
        "dodge",
        "purge",
        "cleanse",
        "deathsDoor",
    }
)


def _validate_int_amount(token: str, amount: str) -> None:
    try:
        int(amount.strip())
    except ValueError as error:
        raise ValueError(f"Modifier amount for {token!r} must be an integer") from error


def _validate_double_amount(token: str, amount: str) -> None:
    try:
        value = float(amount.strip())
    except ValueError as error:
        raise ValueError(f"Modifier amount for {token!r} must be a number") from error
    if not math.isfinite(value):
        raise ValueError(f"Modifier amount for {token!r} must be a finite number")


def _validate_modifier_amount(prefix: str, token: str, amount: str) -> None:
    if prefix in _MODIFIER_INT_PREFIXES:
        _validate_int_amount(token, amount)
    elif prefix in _MODIFIER_DOUBLE_PREFIXES:
        _validate_double_amount(token, amount)


def modifier_token_to_swift(token: str) -> str:
    if ":" not in token:
        raise ValueError(f"Unknown modifier token: {token}")
    prefix, rest = token.split(":", 1)
    if prefix in _MODIFIER_SIMPLE:
        _validate_modifier_amount(prefix, token, rest)
        return f"{_MODIFIER_SIMPLE[prefix]}({rest})"
    if prefix in _MODIFIER_KEYWORD_PREFIXES:
        if ":" not in rest:
            raise ValueError(f"Malformed modifier token {token!r}: expected keyword:amount")
        keyword, amount = rest.split(":", 1)
        if keyword not in VALID_KEYWORDS:
            raise ValueError(f"Unknown keyword {keyword!r} in modifier token {token!r}")
        _validate_modifier_amount(prefix, token, amount)
        if prefix == "damage_dealt":
            return f".damageDealt(.{keyword}, {amount})"
        if prefix == "damage_taken_percent":
            return f".damageTakenPercent(.{keyword}, {amount})"
        return f".damageTakenVulnerability(.{keyword}, {amount})"
    raise ValueError(f"Unknown modifier token: {token}")


def modifier_field_key(token: str) -> tuple[str, str | None]:
    prefix, _, rest = token.partition(":")
    if prefix in _MODIFIER_KEYWORD_PREFIXES:
        keyword, _, _ = rest.partition(":")
        return (prefix, keyword)
    return (prefix, None)


def reject_duplicate_modifier_tokens(tokens: list[str], label: str) -> None:
    seen: dict[tuple[str, str | None], str] = {}
    for token in tokens:
        key = modifier_field_key(token)
        if key in seen:
            raise ValueError(
                f"Duplicate modifier field {key[0]!r} for {label}: "
                f"{token!r} repeats {seen[key]!r}; merge into one token"
            )
        seen[key] = token


def modifiers_swift(raw: str, row_id: str = "") -> str:
    tokens = parse_modifier_tokens(raw)
    reject_duplicate_modifier_tokens(tokens, row_id or "modifiers")
    mods = [modifier_token_to_swift(token) for token in tokens]
    return "[" + ", ".join(mods) + "]"
