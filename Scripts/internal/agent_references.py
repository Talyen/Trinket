"""Content identity for routed references; a fingerprint is not a read receipt."""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from urllib.parse import unquote

from internal.cli import ROOT
from internal.markdown import headings


def content_digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def session_receipt(chat: str, root: Path) -> Path:
    if not chat.strip():
        raise ValueError("session requires a nonempty chat ID")
    identity = content_digest((str(root.resolve()) + "\0" + chat).encode())
    return Path(tempfile.gettempdir()) / f"trinket-agent-{identity}.json"


def fingerprint(root: Path, target: str) -> str:
    name, separator, anchor = target.partition("#")
    path = (root / name).resolve()
    path.relative_to(root.resolve())
    data = path.read_bytes()
    if separator:
        if path.suffix not in {".md", ".mdc"}:
            raise ValueError("anchors require Markdown")
        if not any(entry.slug == unquote(anchor) for entry in headings(data.decode().splitlines())):
            raise ValueError(f"missing heading #{anchor} in {name}")
    # Whole-file identity conservatively invalidates every section after an edit,
    # including changes to surrounding rules or source locations.
    return content_digest(data)


def read_receipt(path: Path, chat: str, root: Path) -> dict:
    if not chat.strip():
        raise ValueError("--chat must identify this chat; do not share receipts between chats")
    empty = {"version": 1, "chat": chat, "root": str(root.resolve()), "reads": {}}
    if not path.exists():
        return empty
    receipt = json.loads(path.read_text())
    if not isinstance(receipt, dict) or any(receipt.get(key) != empty[key] for key in ("version", "chat", "root")):
        raise ValueError("receipt belongs to another chat/repository or has an unsupported version; use a fresh receipt")
    reads = receipt.get("reads")
    if not isinstance(reads, dict) or any(not isinstance(key, str) or not isinstance(value, str)
                                         or not re.fullmatch(r"[0-9a-f]{64}", value) for key, value in reads.items()):
        raise ValueError("invalid receipt reads")
    return receipt


def record_read(path: Path, chat: str, root: Path, target: str, data: bytes) -> None:
    receipt = read_receipt(path, chat, root)
    name, separator, anchor = target.partition("#")
    relative = (root / name).resolve().relative_to(root.resolve()).as_posix()
    reference = relative + ("#" + unquote(anchor) if separator else "")
    # An edited file invalidates all old sections, including sections read at
    # earlier byte identities that happen to match an older whole-file receipt.
    digest = content_digest(data)
    receipt["reads"] = {key: value for key, value in receipt["reads"].items()
                        if key.partition("#")[0] != relative or value == digest}
    receipt["reads"][reference] = digest
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix=".agent-receipt-", delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(receipt, stream, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()


def can_reuse(receipt: dict, root: Path, target: str) -> bool:
    name, separator, anchor = target.partition("#")
    relative = (root / name).resolve().relative_to(root.resolve()).as_posix()
    reference = relative + ("#" + unquote(anchor) if separator else "")
    digest = fingerprint(root, reference)
    reads = receipt["reads"]
    return reads.get(reference) == digest or bool(separator and reads.get(relative) == digest)


def main(argv: list[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("targets", nargs="*")
    parser.add_argument("--session", help="print the temporary receipt path for this chat")
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--chat")
    parser.add_argument("--annotate", action="store_true", help="annotate a routing briefing from stdin; preserve every reference and warning")
    args = parser.parse_args(argv)
    try:
        if args.session is not None:
            if args.targets or args.receipt or args.chat or args.annotate:
                raise ValueError("--session accepts only the chat ID")
            print(session_receipt(args.session, ROOT))
            return 0
        if not args.targets:
            raise ValueError("at least one reference is required")
        if args.annotate:
            if args.receipt is None or args.chat is None:
                raise ValueError("--annotate requires --receipt and --chat")
            receipt = read_receipt(args.receipt, args.chat, ROOT)
            states = {target: can_reuse(receipt, ROOT, target) for target in dict.fromkeys(args.targets)}
            for line in sys.stdin:
                reference = line.strip().split(" —", 1)[0]
                suffix = (" [already read; unchanged]" if states[reference] else " [read if applicable]") if reference in states else ""
                print(line.rstrip("\n") + suffix)
            return 0
        if args.receipt is not None or args.chat is not None:
            raise ValueError("receipt options require --annotate")
        for target in dict.fromkeys(args.targets):
            print(f"  {target} sha256:{fingerprint(ROOT, target)}")
    except (OSError, ValueError, UnicodeError) as error:
        parser.exit(2, f"Fingerprint failed: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
