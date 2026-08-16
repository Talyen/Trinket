#!/usr/bin/env python3
"""Unit tests for SpringBoard first-page icon placement."""

from __future__ import annotations

import plistlib
import tempfile
import unittest
from pathlib import Path

from test_script_regressions import ROOT, load_script

place = load_script("place_home_screen_icon", "place-home-screen-icon.py")


def _state(*, pages: list) -> dict:
    return {
        "buttonBar": ["com.apple.mobilesafari"],
        "iconLists": pages,
        "listUniqueIdentifiers": ["PAGE-0", "PAGE-1"][: len(pages)],
    }


class PlaceHomeScreenIconTests(unittest.TestCase):
    def test_already_first_app_on_first_page_is_noop(self) -> None:
        state = _state(
            pages=[["com.ryanmcintire.Trinket", "com.apple.mobilecal"], ["com.apple.Maps"]]
        )
        status = place.ensure_bundle_on_first_page(state, "com.ryanmcintire.Trinket")
        self.assertEqual(status, "already")
        self.assertEqual(
            state["iconLists"],
            [["com.ryanmcintire.Trinket", "com.apple.mobilecal"], ["com.apple.Maps"]],
        )

    def test_trailing_first_page_icon_moves_ahead_of_stock_apps(self) -> None:
        widget = {"elementType": "widget", "bundleIdentifier": "com.apple.Maps.GeneralMapsWidget"}
        state = _state(pages=[[widget, "com.apple.mobilecal", "com.ryanmcintire.Trinket"], []])
        status = place.ensure_bundle_on_first_page(state, "com.ryanmcintire.Trinket")
        self.assertEqual(status, "moved")
        self.assertEqual(
            state["iconLists"][0],
            [widget, "com.ryanmcintire.Trinket", "com.apple.mobilecal"],
        )

    def test_moves_from_second_page_preserving_widgets(self) -> None:
        widget = {"elementType": "widget", "bundleIdentifier": "com.apple.Maps.GeneralMapsWidget"}
        state = _state(
            pages=[
                [widget, "com.apple.mobilecal"],
                ["com.apple.Fitness", "com.ryanmcintire.Trinket"],
            ]
        )
        status = place.ensure_bundle_on_first_page(state, "com.ryanmcintire.Trinket")
        self.assertEqual(status, "moved")
        self.assertEqual(state["iconLists"][0][0], widget)
        self.assertEqual(
            state["iconLists"],
            [
                [widget, "com.ryanmcintire.Trinket", "com.apple.mobilecal"],
                ["com.apple.Fitness"],
            ],
        )

    def test_missing_without_insert(self) -> None:
        state = _state(pages=[["com.apple.mobilecal"], ["com.apple.Maps"]])
        status = place.ensure_bundle_on_first_page(state, "com.ryanmcintire.Trinket")
        self.assertEqual(status, "missing")
        self.assertEqual(state["iconLists"][0], ["com.apple.mobilecal"])

    def test_insert_if_missing_is_first_app_on_first_page(self) -> None:
        state = _state(pages=[["com.apple.mobilecal"], ["com.apple.Maps"]])
        status = place.ensure_bundle_on_first_page(
            state, "com.ryanmcintire.Trinket", insert_if_missing=True
        )
        self.assertEqual(status, "moved")
        self.assertEqual(state["iconLists"][0], ["com.ryanmcintire.Trinket", "com.apple.mobilecal"])

    def test_strips_duplicates_across_pages(self) -> None:
        state = _state(
            pages=[
                ["com.ryanmcintire.Trinket", "com.apple.mobilecal"],
                ["com.ryanmcintire.Trinket"],
            ]
        )
        status = place.ensure_bundle_on_first_page(state, "com.ryanmcintire.Trinket")
        self.assertEqual(status, "moved")
        self.assertEqual(
            state["iconLists"],
            [["com.ryanmcintire.Trinket", "com.apple.mobilecal"], []],
        )

    def test_folder_dicts_are_not_treated_as_bundle_ids(self) -> None:
        folder = {
            "displayName": "Utilities",
            "listType": "folder",
            "iconLists": [["com.apple.shortcuts"]],
        }
        state = _state(pages=[[folder], ["com.ryanmcintire.Trinket"]])
        status = place.ensure_bundle_on_first_page(state, "com.ryanmcintire.Trinket")
        self.assertEqual(status, "moved")
        self.assertIs(state["iconLists"][0][0], folder)
        self.assertEqual(state["iconLists"][0][1], "com.ryanmcintire.Trinket")

    def test_plist_round_trip_writes_only_on_move(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "IconState.plist"
            original = _state(pages=[["com.apple.mobilecal"], ["com.ryanmcintire.Trinket"]])
            with path.open("wb") as handle:
                plistlib.dump(original, handle, fmt=plistlib.FMT_BINARY)

            check = place.apply_plist(
                path, "com.ryanmcintire.Trinket", insert_if_missing=False, check_only=True
            )
            self.assertEqual(check, "moved")
            with path.open("rb") as handle:
                self.assertEqual(plistlib.load(handle)["iconLists"][1], ["com.ryanmcintire.Trinket"])

            status = place.apply_plist(
                path, "com.ryanmcintire.Trinket", insert_if_missing=False, check_only=False
            )
            self.assertEqual(status, "moved")
            with path.open("rb") as handle:
                written = plistlib.load(handle)
            self.assertEqual(written["iconLists"][0][0], "com.ryanmcintire.Trinket")
            self.assertEqual(written["iconLists"][1], [])

            again = place.apply_plist(
                path, "com.ryanmcintire.Trinket", insert_if_missing=False, check_only=False
            )
            self.assertEqual(again, "already")


if __name__ == "__main__":
    unittest.main()
