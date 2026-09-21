#!/usr/bin/env python3
"""Inspect authored manifest/ability IDs or canonical manifest trigger-field usage."""

from __future__ import annotations

import argparse
from dataclasses import asdict
import shlex
import sys

from internal.cli import ROOT
from internal.content.common import MANIFEST_DIR, read_tsv_records
from internal.content.abilities import located_ability_decls
from internal.content.content_codegen_triggers import _trigger_field_types, parse_trigger_values
from internal.content.homestead import parse_homestead_node_rows
from internal.content.items import parse_affix_rows, parse_item_base_rows
from internal.content.roster import parse_combatant_rows, parse_enemy_rows, parse_trait_rows
from internal.content.stages import parse_stage_rows
from internal.content.talents import parse_talent_rows
from internal.content.inspection import related_references

PARSERS = {
    "talents": parse_talent_rows, "traits": parse_trait_rows, "affixes": parse_affix_rows,
    "homestead_nodes": parse_homestead_node_rows, "combatants": parse_combatant_rows,
    "enemies": parse_enemy_rows, "item_bases": parse_item_base_rows, "stages": parse_stage_rows,
}


def records(kind: str):
    if kind == "abilities":
        for path, line, (symbol, identity, name, tier) in located_ability_decls():
            yield f"{path.relative_to(ROOT)}:{line}", identity, {
                "id": identity, "name": name, "tier": tier, "symbol": f"AbilityCatalog.{symbol}",
            }
        return
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
    query.add_argument("--id", help="exact manifest or ability ID; all Homestead tiers; stages use chapter_id:stage_number")
    query.add_argument("--name", help="case-insensitive player-facing name substring; lists all matching records")
    query.add_argument("--trigger", help="exact canonical Swift trigger field (aliases resolve through codegen)")
    parser.add_argument("--kind", choices=(*PARSERS, "abilities"), help="restrict to one manifest or authored abilities")
    parser.add_argument("--limit", type=int, default=5, help="records per page")
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--full", action="store_true", help="show complete fields in this page")
    parser.add_argument("--references", action="store_true", help="schema, rule, authored implementation and test hints for this page")
    parser.add_argument("--reference-limit", type=int, default=12, help="relationship hints per page")
    parser.add_argument("--reference-offset", type=int, default=0)
    args = parser.parse_args(argv)
    if args.limit < 1 or args.offset < 0 or args.reference_limit < 1 or args.reference_offset < 0:
        parser.error("limits must be positive and offsets nonnegative")
    if args.kind == "abilities" and args.trigger:
        parser.error("--trigger searches manifest DSL fields; abilities require --id")
    try:
        if args.trigger and args.trigger not in _trigger_field_types():
            raise ValueError(f"Unknown canonical trigger field: {args.trigger}")
        matches = []
        kinds = [args.kind] if args.kind else [*PARSERS, *(["abilities"] if args.trigger is None else [])]
        for kind in kinds:
            for location, identity, fields in records(kind):
                if args.id is not None:
                    match = identity == args.id
                elif args.name is not None:
                    match = args.name.casefold() in fields.get('name', fields.get('title', '')).casefold()
                else:
                    match = any(args.trigger in parse_trigger_values(value, identity)
                                for field, value in fields.items() if field.endswith("triggers"))
                if match:
                    matches.append((location, identity, fields))
        if args.offset > len(matches):
            raise ValueError("--offset is beyond the last matching record")
        print("Surface: authored ContentManifest tables and ability tier declarations; generated catalogs are outside this lookup."
              if args.trigger is None else "Surface: authored ContentManifest DSL fields; ability Swift is outside trigger lookup.")
        stop = min(len(matches), args.offset + args.limit)
        for location, identity, fields in matches[args.offset:stop]:
            print(f"{location} — {identity}")
            for key, value in fields.items():
                displayed = value if args.full or len(value) <= 600 else value[:600] + "… [shortened; use --full]"
                print(f"  {key}: {displayed or '(empty)'}")
        print(f"Matched {len(matches)} records; showing {args.offset}:{stop}; omitted {max(0, len(matches) - stop)} after this page.")
        def continuation(offset):
            query_flag, query_value = ('--id', args.id) if args.id is not None else ('--name', args.name) if args.name is not None else ('--trigger', args.trigger)
            command = ["python3", "Scripts/content-inspect.py", query_flag, query_value,
                       "--offset", str(offset), "--limit", str(args.limit)]
            if args.kind:
                command += ["--kind", args.kind]
            if args.full:
                command += ["--full"]
            if args.references:
                command += ['--references', '--reference-limit', str(args.reference_limit)]
            return command
        if stop < len(matches):
            print("Continue: " + shlex.join(continuation(stop)))
        if args.references:
            rows = related_references(ROOT, matches[args.offset:stop])
            if args.reference_offset > len(rows):
                raise ValueError('--reference-offset is beyond the last hint')
            end = min(len(rows), args.reference_offset + args.reference_limit)
            print('Relationship hints for displayed records (literal references, not a complete semantic consumer graph):')
            for row in rows[args.reference_offset:end]:
                print(row)
            print(f'Hints {args.reference_offset}:{end} of {len(rows)}; omitted {len(rows) - end}.')
            if end < len(rows):
                print('Continue hints: ' + shlex.join(continuation(args.offset) + ['--reference-offset', str(end)]))
        return 0 if matches else 1
    except (OSError, ValueError) as error:
        print(f"Inspection failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
