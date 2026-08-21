#!/usr/bin/env python3
"""Small, shared queries for `simctl ... -j` payloads."""

from __future__ import annotations

import json
import re
import sys


def payload() -> dict:
    try:
        value = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return {}
    return value if isinstance(value, dict) else {}


def devices(data: dict):
    for records in data.get("devices", {}).values():
        if isinstance(records, list):
            yield from (record for record in records if isinstance(record, dict))


def main(argv: list[str]) -> int:
    data = payload()
    command = argv[0] if argv else ""
    if command == "udid-for-name" and len(argv) == 2:
        for device in devices(data):
            if device.get("name") == argv[1]:
                print(device.get("udid", ""))
                return 0
        return 1
    if command == "state-for-udid" and len(argv) == 2:
        for device in devices(data):
            if device.get("udid") == argv[1]:
                print(device.get("state", ""))
                return 0
        return 1
    if command == "name-for-udid" and len(argv) == 2:
        for device in devices(data):
            if device.get("udid") == argv[1]:
                print(device.get("name", ""))
                return 0
        return 1
    if command == "count-booted":
        print(sum(1 for device in devices(data) if device.get("state") == "Booted"))
        return 0
    if command == "preview-count":
        all_devices = list(devices(data))
        print(f"{len(all_devices)}\t{sum(1 for device in all_devices if device.get('state') == 'Booted')}")
        return 0
    if command == "booted-managed":
        for device in devices(data):
            name = str(device.get("name", ""))
            if device.get("state") == "Booted" and (name in {"Trinket Run", "Trinket CI"} or re.fullmatch(r"Trinket Agent \d+", name)):
                if device.get("udid"):
                    print(f"{device['udid']}\t{name}")
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
