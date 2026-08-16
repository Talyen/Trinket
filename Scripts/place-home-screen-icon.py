#!/usr/bin/env python3
"""Move a simulator app icon onto the first SpringBoard home screen page."""

from __future__ import annotations

import argparse
import plistlib
import sys
import uuid
from pathlib import Path
from typing import Any


def _page_contains_bundle(page: Any, bundle_id: str) -> bool:
    if not isinstance(page, list):
        return False
    return any(item == bundle_id for item in page)


def _strip_bundle(page: Any, bundle_id: str) -> None:
    if not isinstance(page, list):
        return
    page[:] = [item for item in page if item != bundle_id]


def _first_app_index(page: Any) -> int:
    """Index of the first app-icon string, after widgets/folders."""
    if not isinstance(page, list):
        return 0
    for index, item in enumerate(page):
        if isinstance(item, str):
            return index
    return len(page)


def ensure_bundle_on_first_page(
    state: dict[str, Any],
    bundle_id: str,
    *,
    insert_if_missing: bool = False,
) -> str:
    """Place `bundle_id` as the first app icon on iconLists[0].

    Appending to a full first page lets SpringBoard overflow the new icon onto
    page 2, so the bundle is inserted ahead of the stock apps.

    Returns:
        already: already the first app icon on the first page
        moved: state mutated onto that slot
        missing: bundle is not in iconLists (and insert_if_missing is false)
    """
    pages = state.get("iconLists")
    if not isinstance(pages, list):
        pages = []
        state["iconLists"] = pages

    present = any(_page_contains_bundle(page, bundle_id) for page in pages)
    if not present and not insert_if_missing:
        return "missing"

    first_app = _first_app_index(pages[0]) if pages else 0
    on_first_slot = (
        bool(pages)
        and first_app < len(pages[0])
        and pages[0][first_app] == bundle_id
        and not any(_page_contains_bundle(page, bundle_id) for page in pages[1:])
    )
    if on_first_slot:
        return "already"

    for page in pages:
        _strip_bundle(page, bundle_id)

    if not pages:
        pages.append([])
        identifiers = state.setdefault("listUniqueIdentifiers", [])
        if isinstance(identifiers, list):
            identifiers.append(str(uuid.uuid4()).upper())

    pages[0].insert(_first_app_index(pages[0]), bundle_id)
    return "moved"


def apply_plist(path: Path, bundle_id: str, *, insert_if_missing: bool, check_only: bool) -> str:
    with path.open("rb") as handle:
        state = plistlib.load(handle)
    if not isinstance(state, dict):
        raise ValueError(f"{path} is not a dictionary plist")

    status = ensure_bundle_on_first_page(
        state,
        bundle_id,
        insert_if_missing=insert_if_missing,
    )
    if check_only or status != "moved":
        return status

    with path.open("wb") as handle:
        plistlib.dump(state, handle, fmt=plistlib.FMT_BINARY)
    return status


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plist", required=True, type=Path)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--check", action="store_true", help="Report status without writing")
    parser.add_argument(
        "--insert-if-missing",
        action="store_true",
        help="Add the bundle to page 0 when SpringBoard has not listed it yet",
    )
    args = parser.parse_args(argv)

    if not args.plist.is_file():
        print("missing")
        return 0

    try:
        status = apply_plist(
            args.plist,
            args.bundle_id,
            insert_if_missing=args.insert_if_missing,
            check_only=args.check,
        )
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    print(status)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
