#!/usr/bin/env python3
"""Inspect authored ContentManifest records or canonical trigger-field usage."""

from __future__ import annotations

import argparse
from dataclasses import asdict
import shlex
import subprocess
import sys

from internal.cli import ROOT
from internal.content.common import MANIFEST_DIR, read_tsv_records
from internal.content.content_codegen_triggers import _trigger_field_types, parse_trigger_values
from internal.content.homestead import parse_homestead_node_rows
from internal.content.items import parse_affix_rows, parse_item_base_rows
from internal.content.roster import parse_combatant_rows, parse_enemy_rows, parse_trait_rows
from internal.content.stages import parse_stage_rows
from internal.content.talents import parse_talent_rows

PARSERS = {
    "talents": parse_talent_rows, "traits": parse_trait_rows, "affixes": parse_affix_rows,
    "homestead_nodes": parse_homestead_node_rows, "combatants": parse_combatant_rows,
    "enemies": parse_enemy_rows, "item_bases": parse_item_base_rows, "stages": parse_stage_rows,
}


def records(kind: str):
    path = MANIFEST_DIR / f"{kind}.tsv"
    locations = read_tsv_records(path)[1:]
    rows = PARSERS[kind]()
    if len(rows) != len(locations):
        raise ValueError(f"{path}: parser and source locations disagree")
    for row, (line, _) in zip(rows, locations):
        fields = asdict(row)
        identity = fields.get("id", fields.get("node_id"))
        if identity is None:
            identity = f"{fields['chapter_id']}:{fields['stage_number']}"
        yield f"ContentManifest/{path.name}:{line}", identity, fields


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    query = parser.add_mutually_exclusive_group(required=True)
    query.add_argument("--id", help="exact manifest ID; all Homestead tiers; stages use chapter_id:stage_number")
    query.add_argument("--trigger", help="exact canonical Swift trigger field (aliases resolve through codegen)")
    parser.add_argument("--kind", choices=tuple(PARSERS), help="restrict to one authored manifest")
    parser.add_argument("--limit", type=int, default=5, help="records per page")
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--full", action="store_true", help="show complete fields in this page")
    parser.add_argument("--references", action="store_true", help="bounded literal source/test lookup hints for an exact ID")
    args = parser.parse_args(argv)
    if args.limit < 1 or args.offset < 0 or (args.references and args.id is None):
        parser.error("positive --limit, nonnegative --offset, and --id for --references are required")
    try:
        if args.trigger and args.trigger not in _trigger_field_types():
            raise ValueError(f"Unknown canonical trigger field: {args.trigger}")
        matches = []
        for kind in ([args.kind] if args.kind else PARSERS):
            for location, identity, fields in records(kind):
                if args.id is not None:
                    match = identity == args.id
                else:
                    match = any(args.trigger in parse_trigger_values(value, identity)
                                for field, value in fields.items() if field.endswith("triggers"))
                if match:
                    matches.append((location, identity, fields))
        if args.offset > len(matches):
            raise ValueError("--offset is beyond the last matching record")
        print("Surface: authored ContentManifest tables; ability Swift and generated catalogs are outside this lookup.")
        stop = min(len(matches), args.offset + args.limit)
        for location, identity, fields in matches[args.offset:stop]:
            print(f"{location} — {identity}")
            for key, value in fields.items():
                displayed = value if args.full or len(value) <= 600 else value[:600] + "… [shortened; use --full]"
                print(f"  {key}: {displayed or '(empty)'}")
        print(f"Matched {len(matches)} records; showing {args.offset}:{stop}; omitted {max(0, len(matches) - stop)} after this page.")
        if stop < len(matches):
            command = ["python3", "Scripts/content-inspect.py", "--id" if args.id is not None else "--trigger",
                       args.id if args.id is not None else args.trigger, "--offset", str(stop), "--limit", str(args.limit)]
            if args.kind:
                command += ["--kind", args.kind]
            if args.full:
                command += ["--full"]
            print("Continue: " + shlex.join(command))
        if args.references:
            print("Literal reference hints (not a complete semantic consumer graph):", flush=True)
            for mode in ("source", "tests"):
                result = subprocess.run([sys.executable, str(ROOT / "Scripts/agent-search.py"),
                                         "--mode", mode, "-F", "--", args.id], cwd=ROOT)
                if result.returncode not in (0, 1):
                    return result.returncode
        return 0 if matches else 1
    except (OSError, ValueError) as error:
        print(f"Inspection failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
