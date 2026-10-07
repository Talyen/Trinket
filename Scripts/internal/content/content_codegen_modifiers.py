#!/usr/bin/env python3
"""Modifier-DSL ownership for content codegen."""

from __future__ import annotations

import math
import re

from internal.content.modifier_schema import modifier_definitions


def parse_modifier_tokens(raw: str) -> list[str]:
    if not raw:
        return []
    return [part.strip() for part in raw.split("|") if part.strip()]


_MODIFIERS = {row["token"]: row for row in modifier_definitions()}


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


def parse_typed_int(raw: str, label: str) -> int:
    """Single home for integer trigger/modifier values. Accepts surrounding
    whitespace and explicit +/- signs; rejects non-integers and infinities."""
    try:
        value = raw.strip()
        if not re.fullmatch(r"[+-]?[0-9]+(?:_[0-9]+)*", value):
            raise ValueError("not a Swift integer literal")
        number = int(value)
    except ValueError as error:
        raise ValueError(f"Integer value for {label} must be an integer, got {raw!r}") from error
    if not -(1 << 63) <= number < (1 << 63):
        raise ValueError(f"Integer value for {label} must fit a Swift Int, got {raw!r}")
    return number


def parse_typed_double(raw: str, label: str) -> float:
    """Single home for floating trigger/modifier values. Finite only."""
    try:
        literal = raw.strip()
        if not re.fullmatch(r"[+-]?[0-9]+(?:_[0-9]+)*(?:\.[0-9]+(?:_[0-9]+)*)?(?:[eE][+-]?[0-9]+)?", literal):
            raise ValueError("not a Swift numeric literal")
        value = float(literal)
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


def modifier_token_to_swift(token: str) -> str:
    prefix, separator, amount = token.partition(":")
    definition = _MODIFIERS.get(prefix)
    if not separator or definition is None:
        raise ValueError(f"Unknown modifier token: {token}")
    arguments = ""
    if definition["keyword"]:
        keyword, separator, amount = amount.partition(":")
        if not separator:
            raise ValueError(f"Malformed modifier token {token!r}: expected keyword:amount")
        if keyword not in VALID_KEYWORDS:
            raise ValueError(f"Unknown keyword {keyword!r} in modifier token {token!r}")
        arguments = f".{keyword}, "
    if definition["type"] == "Int":
        parse_typed_int(amount, token)
    else:
        parse_typed_double(amount, token)
    return f".{definition['case']}({arguments}{amount})"


def modifier_field_key(token: str) -> tuple[str, str | None]:
    prefix, _, rest = token.partition(":")
    if _MODIFIERS.get(prefix, {}).get("keyword"):
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
