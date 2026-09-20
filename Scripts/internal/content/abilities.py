"""Abilities content parsing, validation, and generation."""

from __future__ import annotations

from collections.abc import Iterator
from pathlib import Path
import functools
import hashlib
import os
import re
import subprocess
import tempfile

from internal.cli import ROOT
from internal.content.common import GENERATED_DIR, write_generated_file, write_if_changed
from script_diagnostics import excerpt


ABILITY_DIR = ROOT / "Packages" / "TrinketContent" / "Sources" / "TrinketContent" / "Abilities"


TRINKET_CONTENT_PACKAGE = ROOT / "Packages" / "TrinketContent"


ABILITY_INVENTORY_STAMP = ROOT / ".DerivedData" / "AbilityInventory.stamp"


VALID_TIERS = frozenset({"basic", "skill", "ultimate"})


ABILITY_DECL_BUILDERS = r"(?:Ability\()"


ABILITY_DECL_PATTERN = (
    rf"static let (\w+) = {ABILITY_DECL_BUILDERS}\s*"
    r'id: "([^"]+)",\s*name: "([^"]+)",\s*tier: \.(\w+)'
)


ABILITY_TIERS = ("Basic", "Skill", "Ultimate")


@functools.cache
def _read_ability_sources() -> tuple[tuple[Path, str], ...]:
    return tuple((path, path.read_text()) for tier in ABILITY_TIERS
                 for path in [ABILITY_DIR / f"AbilityCatalog+{tier}.swift"])


def located_ability_decls() -> Iterator[tuple[Path, int, tuple[str, str, str, str]]]:
    """Share declaration parsing between codegen and authored-location lookup."""
    for path, source in _read_ability_sources():
        for match in re.finditer(ABILITY_DECL_PATTERN, source):
            yield path, source.count("\n", 0, match.start()) + 1, match.groups()


def iter_ability_decls() -> Iterator[tuple[str, str, str, str]]:
    """Yield (symbol, id, name, tier) for each ability declaration.

    Every `static let X = Ability(` declaration carries id/name/tier, so the
    tier, shorthand, and inventory scans share this one pattern.
    """
    for _, _, declaration in located_ability_decls():
        yield declaration


def collect_ability_symbols() -> set[str]:
    return set(collect_ability_tiers())


def collect_ability_tiers() -> dict[str, str]:
    tiers: dict[str, str] = {}
    for symbol, _, _, tier in iter_ability_decls():
        if symbol in tiers:
            raise ValueError(f"Ability symbol '{symbol}' appears twice in the ability tier catalogs")
        tiers[symbol] = tier
    return tiers


def parse_ability_symbol_list(raw: str) -> list[str]:
    return [part.strip() for part in raw.split(",") if part.strip()]


def ability_symbols_swift(raw: str) -> str:
    symbols = parse_ability_symbol_list(raw)
    return "[" + ", ".join(f".{symbol}" for symbol in symbols) + "]"


def generate_ability_shorthand() -> None:
    entries: list[tuple[str, str]] = []
    for symbol, _, _, _ in iter_ability_decls():
        entries.append((symbol, f"AbilityCatalog.{symbol}"))

    entries.sort(key=lambda item: item[0])
    lines = [f"    static let {symbol} = {target}" for symbol, target in entries]
    body = "public extension Ability {\n" + "\n".join(lines) + "\n}\n"
    write_generated_file(GENERATED_DIR / "AbilityShorthand.generated.swift", body)


def parse_authored_ability_inventory_rows() -> list[tuple[str, str, str]]:
    """Regex-extract id/name/tier from the ability catalog (cross-check only)."""
    rows: list[tuple[str, str, str]] = []
    for _, ability_id, name, tier in iter_ability_decls():
        rows.append((ability_id, name, tier))
    tier_rank = {"basic": 0, "skill": 1, "ultimate": 2}
    rows.sort(key=lambda item: (tier_rank[item[2]], item[1].lower()))
    return rows


def _ability_inventory_digest() -> str:
    inputs = [ROOT / "Scripts/content_codegen.py", ROOT / "Scripts/tool-versions.env"]
    inputs.extend((ROOT / "Scripts/internal/content").glob("*.py"))
    for package in (TRINKET_CONTENT_PACKAGE, ROOT / "Packages/TrinketCore"):
        inputs.append(package / "Package.swift")
        inputs.extend((package / "Sources").rglob("*.swift"))
    hasher = hashlib.sha256()
    for path in sorted(inputs):
        hasher.update(str(path.relative_to(ROOT)).encode() + b"\0")
        hasher.update(path.read_bytes() + b"\0")
    return hasher.hexdigest()


def generate_ability_inventory() -> None:
    """Dump id/name/tier/summary from Swift Ability.summary for humans/agents."""
    out = GENERATED_DIR / "AbilityInventory.generated.tsv"
    expected = parse_authored_ability_inventory_rows()
    expected_ids = {ability_id for ability_id, _, _ in expected}

    force = os.environ.get("TRINKET_FORCE_ABILITY_DUMP") == "1"
    current_digest = _ability_inventory_digest()
    if not force and out.is_file() and ABILITY_INVENTORY_STAMP.is_file():
        if ABILITY_INVENTORY_STAMP.read_text(encoding="utf-8").strip() == current_digest:
            return

    with tempfile.TemporaryDirectory() as directory:
        dump_path = Path(directory) / "AbilityInventory.tsv"
        log_root = Path(os.environ.get("RESULTS_DIR", str(ROOT / ".DerivedData/ContentGeneration")))
        log_root.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(prefix="ability-inventory-", suffix=".log", dir=log_root, delete=False) as log:
            log_path = Path(log.name)
            try:
                completed = subprocess.run(
                    ["swift", "run", "--package-path", str(TRINKET_CONTENT_PACKAGE),
                     "AbilityInventoryDump", str(dump_path)],
                    cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=False,
                )
            except OSError as error:
                log.write(str(error).encode())
                log.flush()
                raise RuntimeError(f"AbilityInventoryDump could not start. Full log: {log_path}\n"
                                   + "\n".join(excerpt(log_path))) from error
        if completed.returncode != 0 or not dump_path.is_file():
            reason = f"failed (exit {completed.returncode})" if completed.returncode else "did not write its output file"
            raise RuntimeError(f"AbilityInventoryDump {reason}. Full log: {log_path}\n"
                               + "\n".join(excerpt(log_path)))
        log_path.unlink()
        tsv = dump_path.read_text(encoding="utf-8")

    header = "id\tname\ttier\tsummary"
    if not tsv.endswith("\n"):
        tsv += "\n"

    lines = [line for line in tsv.splitlines() if line.strip()]
    if not lines or lines[0] != header:
        raise RuntimeError(f"AbilityInventoryDump produced unexpected header: {lines[:1]!r}")

    dumped_ids: set[str] = set()
    for line in lines[1:]:
        parts = line.split("\t")
        if len(parts) != 4:
            raise RuntimeError(f"AbilityInventoryDump row must have 4 columns: {line!r}")
        ability_id, name, tier, summary = parts
        if not ability_id or not name or tier not in VALID_TIERS or not summary:
            raise RuntimeError(f"AbilityInventoryDump row invalid: {line!r}")
        if ability_id in dumped_ids:
            raise RuntimeError(f"AbilityInventoryDump duplicate id: {ability_id}")
        dumped_ids.add(ability_id)

    if dumped_ids != expected_ids:
        missing = sorted(expected_ids - dumped_ids)
        extra = sorted(dumped_ids - expected_ids)
        raise RuntimeError(
            "AbilityInventoryDump IDs do not match authored catalogs: "
            f"missing={missing!r} extra={extra!r}"
        )

    expected_by_id = {ability_id: (name, tier) for ability_id, name, tier in expected}
    for line in lines[1:]:
        ability_id, name, tier, _summary = line.split("\t")
        expected_name, expected_tier = expected_by_id[ability_id]
        if name != expected_name or tier != expected_tier:
            raise RuntimeError(
                f"AbilityInventoryDump metadata mismatch for {ability_id}: "
                f"got name={name!r} tier={tier!r}, "
                f"expected name={expected_name!r} tier={expected_tier!r}"
            )

    # Skip rewrite when unchanged so generate no-ops do not bump mtimes under
    # Packages/TrinketContent (Xcode watches the package tree).
    write_if_changed(out, tsv)

    ABILITY_INVENTORY_STAMP.parent.mkdir(parents=True, exist_ok=True)
    ABILITY_INVENTORY_STAMP.write_text(current_digest, encoding="utf-8")
