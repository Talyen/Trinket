#!/usr/bin/env python3
"""Modifier-DSL ownership for content codegen."""

from __future__ import annotations

import math

from internal.content.modifier_schema import modifier_definitions


def parse_modifier_tokens(raw: str) -> list[str]:
    if not raw:
        return []
    return [part.strip() for part in raw.split("|") if part.strip()]


_DEFINITIONS = modifier_definitions()
_MODIFIER_SIMPLE = {row["token"]: "." + row["case"] for row in _DEFINITIONS if not row["keyword"]}
_MODIFIER_INT_PREFIXES = frozenset(row["token"] for row in _DEFINITIONS if row["type"] == "Int")
_MODIFIER_DOUBLE_PREFIXES = frozenset(row["token"] for row in _DEFINITIONS if row["type"] == "Double")
_MODIFIER_KEYWORD_PREFIXES = {row["token"]: row["case"] for row in _DEFINITIONS if row["keyword"]}


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
        "thorns",
    }
)


def _validate_int_amount(token: str, amount: str) -> None:
    parse_typed_int(amount, token)


def _validate_double_amount(token: str, amount: str) -> None:
    parse_typed_double(amount, token)


def parse_typed_int(raw: str, label: str) -> int:
    """Single home for integer trigger/modifier values. Accepts surrounding
    whitespace and explicit +/- signs; rejects non-integers and infinities."""
    try:
        return int(raw.strip())
    except ValueError as error:
        raise ValueError(f"Integer value for {label} must be an integer, got {raw!r}") from error


def parse_typed_double(raw: str, label: str) -> float:
    """Single home for floating trigger/modifier values. Finite only."""
    try:
        value = float(raw.strip())
    except ValueError as error:
        raise ValueError(f"Numeric value for {label} must be a number, got {raw!r}") from error
    if not math.isfinite(value):
        raise ValueError(f"Numeric value for {label} must be a finite number, got {raw!r}")
    return value


def parse_typed_bool(raw: str, label: str) -> bool:
    """Single home for boolean trigger values. Accepts true/false/1 (any case
    for the words); anything else must be dropped at the call site."""
    normalized = raw.strip().lower()
    if normalized in ("true", "1"):
        return True
    if normalized == "false":
        return False
    raise ValueError(
        f"Trigger value for {label} must be true or false, "
        f"got {raw!r}; drop the token for false"
    )


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
        return f".{_MODIFIER_KEYWORD_PREFIXES[prefix]}(.{keyword}, {amount})"
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
