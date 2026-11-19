#!/usr/bin/env python3
"""Drive one take on a paired physical Wi-Fi iPhone and retrieve its original movie."""
import argparse
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import uuid

from internal.cli import write_json_atomic
from internal.device_selection import select_device

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = "com.ryanmcintire.Trinket"
RECORDER = BUNDLE + ".TrailerRecorder"


def device_json(*args):
    command = ["xcrun", "devicectl", "--timeout", "25", "--quiet", "--json-output", "-", *args]
    return json.loads(subprocess.check_output(command, text=True, timeout=35))["result"]


def installed_phone(requested):
    entry = select_device(device_json("list", "devices")["devices"], requested)
    props = entry.get("properties", {})
    hardware = props.get("hardware", entry.get("hardwareProperties", {}))
    connection = props.get("connection", entry.get("connectionProperties", {}))
    if connection.get("transportType", "").lower() not in {"localnetwork", "wifi", "network"}:
        raise ValueError("Select a paired iPhone connected over Wi-Fi.")
    if hardware.get("deviceType") != "iPhone":
        raise ValueError("This tour requires an iPhone.")
    udid = hardware["udid"]
    device_json("device", "info", "displays", "--device", udid)
    apps = device_json("device", "info", "apps", "--device", udid, "--bundle-id", BUNDLE)["apps"]
    app = next((app for app in apps if app.get("bundleIdentifier") == BUNDLE), None)
    if not app:
        raise ValueError("Install Trinket before capture.")
    return udid, {key: app[key] for key in ("bundleIdentifier", "version", "bundleVersion")}


def keep_times(shots, clock):
    keep = []
    previous_end = 0
    for shot in shots:
        start = shot["start"] - clock["start"]
        end = shot["end"] - clock["start"]
        if not previous_end <= start < end <= clock["duration"]:
            raise ValueError(f"Shot outside original recording or out of order: {shot['id']}")
        keep.append({"id": shot["id"], "start": start, "end": end})
        if "card" in shot:
            keep[-1]["card"] = shot["card"]
        previous_end = end
    if not keep:
        raise ValueError("No shots in test attachment.")
    return {"shots": keep}


def cut_gestures(handles, duration):
    recipe = json.loads((ROOT / "Scripts/LaunchTrailer/edit-recipe.json").read_text())
    shots = []
    for handle in handles["shots"]:
        shot_id = handle["id"]
        timing = recipe[shot_id]
        start = round((handle["start"] + timing["offset"]) * 60) / 60
        end = start + round(timing["duration"] * 60) / 60
        if start < (shots[-1]["end"] if shots else 0) or end > duration:
            raise ValueError(f"Check the gesture handles for {shot_id}; the planned cut overlaps or exceeds the take.")
        shot = {"id": shot_id, "start": start, "end": end}
        if "card" in handle:
            shot["card"] = handle["card"]
        if timing.get("effects"):
            shot["effects"] = timing["effects"]
        shots.append(shot)
    return {"shots": shots}


def continuous_boss_shots(handles):
    """Keep one window from first tap through the last manual play for each boss."""
    marks = handles["shots"]
    spires = [m["id"].removesuffix("-ready") for m in marks if m["id"].endswith("-ready")]
    if not spires or len(set(spires)) != len(spires):
        raise ValueError("Showcase requires one entry marker for each boss.")
    shots = []
    for spire in spires:
        action = f"boss-play-{spire}"
        plays = [m for m in marks if m["id"].startswith(action + "-")]
        if len(plays) < 2:
            raise ValueError(f"Showcase needs two card plays for {spire}.")
        shot = {"id": action, "start": plays[0]["start"], "end": plays[-1]["end"]}
        if shots:
            shot["dissolve"] = 0.20
        shots.append(shot)
    return {"shots": shots}


def run_tour(udid, app, output, rehearsal, team, boss_showcase, boss_lyrics=False, spires=(), press_pickups=None, contract=False):
    output.mkdir(parents=True, exist_ok=False)
    take = str(uuid.uuid4()).upper()
    write_json_atomic(output / "take.json", {
        "device": udid, "installedApp": app, "take": take, "rehearsal": rehearsal,
        "bossShowcase": boss_showcase, "bossLyrics": boss_lyrics, "spires": spires,
        "pressPickups": bool(press_pickups), "pressParty": press_pickups, "contract": contract,
    })
    destination = ["-destination", "platform=iOS,id=" + udid]
    with tempfile.TemporaryDirectory(prefix="trinket-tour-") as build:
        root = Path(build)
        project = root / "TrinketTrailer.xcodeproj"
        for source in (ROOT / "Scripts/LaunchTrailer").iterdir():
            if source.is_file():
                shutil.copy2(source, root)
        subprocess.run(["xcodegen", "generate", "--spec", str(root / "project.yml"), "--project", build], check=True)
        products = root / "Products"
        subprocess.run(["xcodebuild", "-quiet", "build-for-testing", "-project", str(project),
                        "-scheme", "PhysicalTour", *destination, "-derivedDataPath", str(root / "build"),
                        "-allowProvisioningUpdates", "DEVELOPMENT_TEAM=" + team, "SYMROOT=" + str(products)],
                       check=True)
        (xctestrun,) = products.glob("PhysicalTour_*.xctestrun")
        config = plistlib.loads(xctestrun.read_bytes())
        test = config["PhysicalTour"]
        test["PreferredScreenCaptureFormat"] = "screenshots"
        test["UserAttachmentLifetime"] = "keepAlways"
        if contract:
            test["EnvironmentVariables"]["TRINKET_CONTRACT_CAPTURE"] = "1"
        if press_pickups:
            test["EnvironmentVariables"]["TRINKET_PRESS_PICKUPS"] = press_pickups
        if boss_showcase or boss_lyrics:
            test["EnvironmentVariables"]["TRINKET_SHOWCASE"] = "1"
        if boss_lyrics:
            test["EnvironmentVariables"]["TRINKET_LYRIC_CAPTURE"] = "1"
        if spires:
            test["EnvironmentVariables"]["TRINKET_SPIRES"] = ",".join(spires)
        if not rehearsal:
            subprocess.run(["xcrun", "devicectl", "device", "install", "app", "--device", udid,
                            str(products / "Debug-iphoneos/TrailerRecorder.app")], check=True)
            test["EnvironmentVariables"]["TRINKET_TAKE"] = take
        xctestrun.write_bytes(plistlib.dumps(config))
        result = output / "tour.xcresult"
        command = ["xcodebuild", "test-without-building", "-xctestrun", str(xctestrun), *destination,
                   "-parallel-testing-enabled", "NO", "-resultBundlePath", str(result), "-collect-test-diagnostics", "never"]
        with (output / "route.log").open("w", buffering=1) as log, subprocess.Popen(
                command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as test_process:
            for line in test_process.stdout:
                print(line, end="", flush=True)
                log.write(line)
            code = test_process.wait()
    attachments = output / "attachments"
    if result.exists():
        subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                        "--output-path", str(attachments)], check=True)
    if not rehearsal:
        # On a route failure preserve a finalized partial take for diagnosis.
        copy = ["xcrun", "devicectl", "device", "copy", "from", "--device", udid, "--domain-type",
                "appDataContainer", "--domain-identifier", RECORDER, "--timeout", "300" if boss_lyrics else "150"]
        for name in ("clock.json", "continuous.mp4"):
            transfer = subprocess.run([*copy, "--source", f"Documents/{take}/{name}",
                                       "--destination", str(output / name)])
            if transfer.returncode:
                if not code:
                    transfer.check_returncode()
                break
    if code:
        raise RuntimeError(f"Physical tour failed. Inspect {output / 'route.log'}")
    manifest = json.loads((attachments / "manifest.json").read_text())
    (marks,) = [a for test in manifest for a in test["attachments"]
                if a["suggestedHumanReadableName"].startswith("Trinket Shot Times")]
    shots = json.loads((attachments / marks["exportedFileName"]).read_text())
    write_json_atomic(output / "shots.json", shots)
    if not rehearsal:
        clock = json.loads((output / "clock.json").read_text())
        handles = keep_times(shots, clock)
        write_json_atomic(output / "handles.json", handles)
        if boss_lyrics or press_pickups or contract:
            timeline = handles
        elif boss_showcase:
            timeline = continuous_boss_shots(handles)
        else:
            timeline = cut_gestures(handles, clock["duration"])
        write_json_atomic(output / "keep.json", timeline)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True, help="Exact iPhone name or UDID")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--rehearse", action="store_true", help="Run the route without capturing video.")
    tours = parser.add_mutually_exclusive_group()
    tours.add_argument("--boss-showcase", action="store_true", help="Record the seven Spire bosses with the debug capture build.")
    tours.add_argument("--boss-lyrics", action="store_true", help="Capture each boss theme and its live lyrics in Auto Battle.")
    tours.add_argument("--contract", action="store_true", help="Record a Contract from the board through its victory rewards.")
    tours.add_argument("--press-pickups", nargs="?", const="wizard", choices=["wizard", "knight", "gear", "countess", "roster"],
                       help="Record the chosen party and ability, gear details, the Countess route, or Recruit, ability and Voyage pickups.")
    parser.add_argument("--spire", action="append", default=[], help="Limit a boss capture to a named Spire ID. Repeat to include more.")
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--team", help="Defaults to the development team in the game project.")
    args = parser.parse_args()
    if args.spire and not (args.boss_showcase or args.boss_lyrics):
        parser.error("--spire requires a boss capture route.")
    udid, app = installed_phone(args.device)
    print(f"Wi-Fi iPhone {udid}, Trinket {app['version']} ({app['bundleVersion']})", flush=True)
    if args.check:
        return
    if not args.output_dir:
        parser.error("--output-dir is required for a take.")
    team = args.team or re.search(r'^    DEVELOPMENT_TEAM: "(\w+)"', (ROOT / "project.yml").read_text(), re.M)[1]
    run_tour(udid, app, args.output_dir.resolve(), args.rehearse, team, args.boss_showcase,
             args.boss_lyrics, args.spire, press_pickups=args.press_pickups, contract=args.contract)


if __name__ == "__main__":
    main()
