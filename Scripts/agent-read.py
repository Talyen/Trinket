#!/usr/bin/env python3
"""Read Markdown sections, source line ranges, or declaration-location outlines."""

from __future__ import annotations

import argparse
import re
import shlex
import sys
from pathlib import Path
from urllib.parse import unquote

from internal.markdown import headings
from internal.cli import ROOT
from internal.agent_arguments import AgentArgumentParser
from internal.source_declarations import source_declarations

DOCUMENT_CHAR_BUDGET = 12_000
RANGE_SUFFIXES = {".sh", ".env", ".json", ".yml", ".yaml", ".toml", ".tsv", ".txt",
                  ".mjs", ".js", ".ts", ".tsx", ".metal", ".plist", ".entitlements",
                  ".xcprivacy", ".xctestplan"}

def argument_parser() -> argparse.ArgumentParser:
    parser = AgentArgumentParser("agent-read.py", description=__doc__)
    parser.add_argument("targets", nargs="*", help="repository files or Markdown #anchors; read each once with the same flags")
    parser.add_argument("--request", action="append", default=[], help="repeat quoted per-target arguments, e.g. 'file.py --symbol main'; no shell execution")
    parser.add_argument("--outline", action="store_true", help="list anchors and source ranges instead of document text")
    parser.add_argument("--full", action="store_true", help="intentionally read an entire supported text file")
    parser.add_argument("--lines", help="explicit inclusive source range START:END")
    parser.add_argument("--offset", type=int, default=0, help="source-outline entry offset")
    parser.add_argument("--limit", type=int, default=60, help="source-outline page length")
    parser.add_argument("--include-locals", action="store_true", help="include function-local declarations")
    parser.add_argument("--symbol", action="append", default=[], help="read a complete declaration; repeat for multiple symbols")
    parser.add_argument("--signatures", action="store_true", help="show declaration headers and attached comments, without bodies")
    parser.add_argument("--kind", choices=("methods", "properties", "types"), help="filter source outlines/signatures")
    parser.add_argument("--match", help="case-insensitive name substring for source outlines/signatures")
    return parser


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = argument_parser()
    args = parser.parse_intermixed_args(argv)
    if not args.targets and not args.request:
        parser.error("supply targets or --request 'path [read flags]'")
    if not args.request:
        return max(read_target(target, args, root) for target in dict.fromkeys(args.targets))
    read_options = ("outline", "full", "lines", "offset", "limit", "include_locals", "symbol", "signatures", "kind", "match")
    defaults = parser.parse_args([])
    if args.targets or any(getattr(args, key) != getattr(defaults, key) for key in read_options):
        parser.error("--request supplies each target and its read flags; use per-request read flags")
    statuses = []
    seen = set()
    request_parser = argument_parser()

    def request_error(message: str) -> None:
        raise ValueError(message)

    request_parser.error = request_error
    for request in args.request:
        try:
            options = request_parser.parse_args(shlex.split(request))
            if len(options.targets) != 1 or options.request:
                raise ValueError("each --request needs one target and read flags")
            identity = (options.targets[0], *(repr(getattr(options, key)) for key in read_options))
            if identity in seen:
                continue
            seen.add(identity)
            statuses.append(read_target(options.targets[0], options, root))
        except (ValueError, SystemExit) as error:
            print(f"Read request failed: {request}: {error}\nTry: python3 Scripts/agent-read.py --help", file=sys.stderr)
            statuses.append(2)
    return max(statuses)


def recovery_command(target: str, args: argparse.Namespace, root: Path) -> list[str]:
    name, separator, anchor = target.partition("#")
    path = (root / name).resolve()
    command = ["python3", "Scripts/agent-read.py", target]
    try:
        path.relative_to(root.resolve())
        lines = path.read_text(encoding="utf-8").splitlines()
        if not lines:
            raise ValueError("empty file")
        if args.lines and not separator:
            command = command[:2] + [name, '--lines', f'1:{min(80, len(lines))}']
        elif path.suffix in {".md", ".mdc"}:
            if separator and not any(entry.slug == unquote(anchor) for entry in headings(lines)):
                command = command[:2] + [name, "--outline"]
            elif not separator:
                command += ["--full"] if args.full else ["--outline"]
        elif path.suffix in {".swift", ".py"}:
            command = command[:2] + [name]
            command += ["--lines", f"1:{len(lines)}"] if args.full else ["--outline"]
        elif path.suffix in RANGE_SUFFIXES:
            command = command[:2] + [name, "--lines", f"1:{len(lines) if args.full else min(80, len(lines))}"]
        else:
            raise ValueError("unsupported text")
        return command
    except (OSError, ValueError, UnicodeError):
        mode = "docs" if path.suffix in {".md", ".mdc"} else "source" if path.suffix in {".swift", ".py"} else "assets"
        return ["python3", "Scripts/agent-search.py", "--mode", mode, "--files", "--", re.escape(Path(name).name)]


def read_target(target: str, args: argparse.Namespace, root: Path) -> int:
    name, separator, anchor = target.partition("#")
    path = (root / name).resolve()
    try:
        if args.offset < 0 or args.limit < 1:
            raise ValueError("outline offset must be nonnegative and limit positive")
        if args.full and (args.outline or args.lines or args.symbol or args.include_locals
                          or args.signatures or args.kind or args.match):
            raise ValueError("--full cannot combine with other read modes")
        relative = path.relative_to(root.resolve()).as_posix()
        supported = {".md", ".mdc", ".swift", ".py"}
        if args.lines or args.full:
            supported |= RANGE_SUFFIXES
        if not name or path.suffix not in supported:
            raise ValueError("target must be Markdown, Swift, or Python; shell/config text requires --lines or --full within the repository")
        if separator and path.suffix not in {".md", ".mdc"}:
            raise ValueError("anchors require Markdown")
        data = path.read_bytes()
        source = data.decode("utf-8")
        lines = source.splitlines()
        if (args.signatures or args.kind or args.match) and path.suffix not in {".swift", ".py"}:
            raise ValueError("signatures and declaration filters require Swift or Python")
        if (args.kind or args.match) and not (args.outline or args.signatures):
            raise ValueError("declaration filters require --outline or --signatures")
        if args.full and path.suffix not in {".md", ".mdc"}:
            print(f"{relative}:1-{len(lines)} (complete text file)")
            for number, line in enumerate(lines, 1):
                print(f"{number}: {line}")
            return 0
        if args.lines:
            if separator or args.outline or args.symbol or args.signatures:
                raise ValueError("--lines cannot be combined with an anchor or --outline")
            start, end = map(int, args.lines.split(":"))
            if not 1 <= start <= end <= len(lines):
                raise ValueError(f"line range must be within 1:{len(lines)}")
            print(f"{relative}:{start}-{end} (requested range; not a completeness claim)")
            for number in range(start, end + 1):
                print(f"{number}: {lines[number - 1]}")
            return 0
        if path.suffix in {".swift", ".py"}:
            navigation = args.outline or args.signatures
            if separator or navigation == bool(args.symbol):
                raise ValueError("source files require --outline, --symbol, or --lines; outline bounds must be nonnegative/positive")
            entries = source_declarations(path, source, args.include_locals)
            if args.symbol:
                selected = []
                ambiguous = []
                for symbol in args.symbol:
                    matches = [entry for entry in entries if entry.name == symbol or entry.name.rsplit(".", 1)[-1] == symbol]
                    if not matches:
                        raise ValueError(f"missing declaration {symbol!r}; use --outline")
                    if len(matches) != 1:
                        ambiguous.append(symbol)
                    for entry in matches:
                        if entry not in selected:
                            selected.append(entry)
                if ambiguous:
                    print(f"Ambiguous symbol(s) {', '.join(ambiguous)}; use a qualified name or --lines START:END:")
                    if args.offset > len(selected):
                        raise ValueError('--offset is beyond the last candidate')
                    stop = min(len(selected), args.offset + args.limit)
                    for entry in selected[args.offset:stop]:
                        print(f"  {entry.start}:{entry.end} {entry.kind} {entry.name}")
                    print(f'Candidates {args.offset}:{stop} of {len(selected)}; omitted {len(selected) - stop}.')
                    if stop < len(selected):
                        command = ['python3', 'Scripts/agent-read.py', relative]
                        for symbol in args.symbol:
                            command += ['--symbol', symbol]
                        if args.include_locals:
                            command.append('--include-locals')
                        print('Continue: ' + shlex.join(command + ['--offset', str(stop), '--limit', str(args.limit)]))
                    return 2
                for entry in selected:
                    print(f"{relative}:{entry.start}-{entry.end} (complete lexical declaration: {entry.name})")
                    for number in range(entry.start, entry.end + 1):
                        print(f"{number}: {lines[number - 1]}")
                return 0
            kinds = {"methods": {"func", "def", "init", "deinit", "subscript"},
                     "properties": {"var", "let"},
                     "types": {"struct", "class", "enum", "actor", "protocol", "extension", "typealias", "associatedtype"}}
            if args.kind:
                entries = [entry for entry in entries if entry.kind in kinds[args.kind]]
            if args.match:
                entries = [entry for entry in entries if args.match.casefold() in entry.name.casefold()]
            if args.offset > len(entries):
                raise ValueError("--offset is beyond the last outline entry")
            stop = min(len(entries), args.offset + args.limit)
            print(f"{relative} — lexical declaration ranges; {'includes locals' if args.include_locals else 'types and members only'}")
            for entry in entries[args.offset:stop]:
                print(f"  {entry.start}:{entry.end} {entry.kind} {entry.name}")
                if args.signatures:
                    if entry.documentation:
                        for line in entry.documentation.splitlines():
                            print(f"    {line.strip()}")
                    print("    " + " ".join(line.strip() for line in entry.signature.splitlines()))
            print(f"Entries {args.offset}:{stop} of {len(entries)}; omitted {len(entries) - stop} after this page.")
            if stop < len(entries):
                command = ["python3", "Scripts/agent-read.py", relative]
                command += ["--signatures"] if args.signatures else ["--outline"]
                command += ["--offset", str(stop), "--limit", str(args.limit)]
                if args.kind:
                    command += ["--kind", args.kind]
                if args.match:
                    command += ["--match", args.match]
                if args.include_locals:
                    command.append("--include-locals")
                print("Continue: " + shlex.join(command))
            return 0
        if args.symbol or args.include_locals:
            raise ValueError("--symbol and --include-locals require Swift or Python")
        entries = headings(lines)
        selected = None
        if separator:
            selected = next((entry for entry in entries if entry.slug == unquote(anchor)), None)
            if selected is None:
                raise ValueError(f"missing heading #{anchor}; use --outline {name}")
        start, end = (selected.start, selected.end) if selected else (1, len(lines))
        automatic_outline = not separator and not args.full and len(source) > DOCUMENT_CHAR_BUDGET
        if args.outline or automatic_outline:
            if automatic_outline:
                print(f"Navigation only: {len(source)} characters exceeds the {DOCUMENT_CHAR_BUDGET}-character default; document text has NOT been read.")
                print("Read a section: python3 Scripts/agent-read.py '" + relative + "#<anchor>'")
                command = ["python3", "Scripts/agent-read.py", relative, "--full"]
                print("Read full document: " + shlex.join(command))
            visible = [entry for entry in entries if start <= entry.start <= end]
            if args.offset > len(visible):
                raise ValueError("--offset is beyond the last outline entry")
            stop = min(len(visible), args.offset + args.limit)
            for entry in visible[args.offset:stop]:
                print(f"{relative}#{entry.slug} [{entry.start}-{entry.end}] {'#' * entry.level} {entry.title}")
            if not visible:
                print("No headings; use --full or --lines START:END to read the document.")
            if stop < len(visible):
                print(f"Omitted {len(visible) - stop} headings.")
                command = ["python3", "Scripts/agent-read.py", target,
                           "--outline", "--offset", str(stop), "--limit", str(args.limit)]
                print("Continue: " + shlex.join(command))
        else:
            print(f"{relative}:{start}-{end} (complete {'section' if selected else 'document'})")
            if selected and selected.parents:
                print("Parent headings:")
                for index in selected.parents:
                    parent = entries[index]
                    print(f"{parent.start}: {lines[parent.start - 1]}")
            for number in range(start, end + 1):
                print(f"{number}: {lines[number - 1]}")
        return 0
    except (OSError, ValueError, RuntimeError, SyntaxError, UnicodeError) as error:
        print(f"Read failed: {target}: {error}", file=sys.stderr)
        retry = recovery_command(target, args, root)
        label = "Read the section separately: " if separator and retry[2] == target else "Try: "
        print(label + shlex.join(retry), file=sys.stderr)
        if separator and (args.lines or args.outline or args.symbol or args.signatures):
            print("Batch flags apply to every target; put ranged/full reads in a separate invocation.", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
