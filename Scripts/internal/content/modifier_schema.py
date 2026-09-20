"""Shared modifier vocabulary and mechanical Swift generation; rules stay authored."""

from __future__ import annotations

import json
import re
from pathlib import Path

from internal.content.common import GENERATED_DIR, write_generated_file

SCHEMA = Path(__file__).with_name("modifiers.json")


def modifier_definitions(path: Path = SCHEMA) -> list[dict]:
    rows = json.loads(path.read_text(encoding="utf-8"))
    tokens, cases = set(), set()
    for row in rows:
        if (set(row) != {"token", "case", "type", "keyword"}
                or not re.fullmatch(r"[a-z][a-z0-9_]*", row["token"])
                or not re.fullmatch(r"[a-z][A-Za-z0-9]*", row["case"])
                or row["type"] not in {"Int", "Double"}
                or type(row["keyword"]) is not bool):
            raise ValueError(f"Invalid modifier definition: {row}")
        if row["token"] in tokens or row["case"] in cases:
            raise ValueError(f"Duplicate modifier token or Swift case: {row}")
        tokens.add(row["token"])
        cases.add(row["case"])
    if not rows:
        raise ValueError("Modifier definitions must not be empty")
    return rows


def render_modifiers(rows: list[dict]) -> str:
    lines = ["public enum AffixModifier: Equatable, Hashable, Codable, Sendable {"]
    for row in rows:
        arguments = ("Keyword, " if row["keyword"] else "") + row["type"]
        lines.append(f"    case {row['case']}({arguments})")
    lines += ["}", "", "public extension AffixModifier {"]
    for name, result in (("isPercent", "Bool"), ("numericValue", "Double")):
        lines += [f"    var {name}: {result} {{", "        switch self {"]
        for row in rows:
            if name == "isPercent":
                value = "true" if row["type"] == "Double" else "false"
                lines.append(f"        case .{row['case']}: {value}")
            else:
                arguments = "_, v" if row["keyword"] else "v"
                value = "Double(v)" if row["type"] == "Int" else "v"
                lines.append(f"        case let .{row['case']}({arguments}): {value}")
        lines += ["        }", "    }", ""]
    for name, kind in (("mapInt", "Int"), ("mapPercent", "Double")):
        lines += [f"    func {name}(_ transform: ({kind}) -> {kind}) -> AffixModifier {{", "        switch self {"]
        for row in rows:
            if row["type"] == kind:
                arguments = "kw, v" if row["keyword"] else "v"
                transformed = "kw, transform(v)" if row["keyword"] else "transform(v)"
                lines.append(f"        case let .{row['case']}({arguments}): .{row['case']}({transformed})")
        lines += ["        default: self", "        }", "    }", ""]
    return "\n".join(lines).rstrip() + "\n}"


def generate_modifiers() -> None:
    write_generated_file(GENERATED_DIR / "AffixModifier.generated.swift", render_modifiers(modifier_definitions()))
