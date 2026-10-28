"""Resolve an unambiguous paired physical device from CoreDevice inventories."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile


def select_device(devices: list[dict], requested: str | None) -> dict:
    candidates = []
    for device in devices:
        props = device.get("properties", {})
        hardware = props.get("hardware", device.get("hardwareProperties", {}))
        connection = props.get("connection", device.get("connectionProperties", {}))
        state = props.get("state", device.get("deviceProperties", {}))
        identities = (device.get("identifier"), hardware.get("udid"), state.get("name"))
        if hardware.get("reality") == "physical" and connection.get("pairingState") == "paired":
            if requested is None or requested in identities:
                candidates.append(device)
    if len(candidates) != 1:
        raise ValueError("Select exactly one paired physical device with --device <UDID|name>.")
    return candidates[0]


def main():
    with tempfile.TemporaryDirectory(prefix="trinket-devices-") as directory:
        inventory = Path(directory) / "devices.json"
        subprocess.run(["xcrun", "devicectl", "list", "devices", "--quiet", "--timeout", "30",
                        "--json-output", str(inventory)], check=True, timeout=40)
        device = select_device(json.loads(inventory.read_text())["result"]["devices"], None)
        identifier = device.get("identifier")
        if not isinstance(identifier, str) or not identifier:
            raise ValueError("Selected device has no CoreDevice identifier")
        print(identifier)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        raise SystemExit(f"Device selection failed: {error}")
