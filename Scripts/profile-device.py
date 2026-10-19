#!/usr/bin/env python3
"""Prepare and validate app-scoped CPU/hitch recordings on a physical iPhone."""

from __future__ import annotations

import argparse
import datetime as dt
from dataclasses import dataclass
import errno
import fcntl
import json
import math
import os
from pathlib import Path
import plistlib
import pty
import re
import selectors
import signal
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = "com.ryanmcintire.Trinket"
SCHEMAS = ("time-profile", "hitches-frame-lifetimes")


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


def stop_owned(process: subprocess.Popen) -> None:
    """Only signal the session created for this command, never shared Apple services."""
    for sig, seconds in ((signal.SIGINT, 5), (signal.SIGTERM, 3), (signal.SIGKILL, 3)):
        if process.poll() is not None:
            return
        try:
            os.killpg(process.pid, sig)
            process.wait(timeout=seconds)
        except ProcessLookupError:
            return
        except subprocess.TimeoutExpired:
            continue


@dataclass
class RecordingWatchdog:
    began: float
    duration: int
    startup: int
    recording_at: float | None = None
    finishing: bool = False
    tail: str = ""

    def observe(self, text: str, now: float) -> float:
        self.tail = (self.tail + text)[-4096:]
        if self.recording_at is None and "Ctrl-C to stop" in self.tail:
            self.recording_at = now
        self.finishing |= "Reached specified time limit" in self.tail or "ending recording" in self.tail
        # Saving has no guessed wall-clock budget. Keep this transition even
        # when subsequent symbolication output scrolls the marker out of tail.
        if self.finishing:
            return math.inf
        if self.recording_at is not None:
            return self.recording_at + self.duration + 30
        return self.began + self.startup


def run(command: list[str], log: Path, timeout: int | None = 60,
        duration: int | None = None, startup: int = 120) -> None:
    print(f"Running: {' '.join(map(str, command))}", flush=True)
    master, slave = pty.openpty()
    process = None
    selector = selectors.DefaultSelector()
    output = ""
    recording_error = False
    began = time.monotonic()
    watchdog = RecordingWatchdog(began, duration, startup) if duration is not None else None
    try:
        process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL,
                                   stdout=slave, stderr=slave, start_new_session=True)
        os.close(slave)
        slave = -1
        selector.register(master, selectors.EVENT_READ)
        with log.open("wb") as stream:
            while selector.get_map():
                for key, _ in selector.select(0.2):
                    try:
                        chunk = os.read(key.fd, 65536)
                    except OSError as error:
                        if error.errno != errno.EIO:
                            raise
                        chunk = b""
                    if not chunk:
                        selector.unregister(master)
                        continue
                    stream.write(chunk)
                    stream.flush()
                    text = chunk.decode(errors="replace")
                    print(text, end="", flush=True)
                    output = (output + text)[-65536:]
                    recording_error |= "Device got disconnected" in output or "[Error]" in output
                    if watchdog is not None:
                        watchdog.observe(text, time.monotonic())
                if process.poll() is not None and not selector.get_map():
                    break
                deadline = began + timeout if timeout is not None else math.inf
                if watchdog is not None:
                    deadline = watchdog.observe("", time.monotonic())
                    if recording_error:
                        raise RuntimeError(f"Instruments reported a recording error; see {log}. Use --build or --app if debugging permission was denied.")
                if time.monotonic() > deadline:
                    raise RuntimeError(f"Command stalled; retained diagnostics at {log}.")
            status = process.wait()
        if status:
            hint = " Use --build or --app with a development-signed Release build." if "get-task-allow" in output else ""
            raise RuntimeError(f"Command failed ({status}); see {log}.{hint}")
    finally:
        if process is not None:
            stop_owned(process)
        selector.close()
        os.close(master)
        if slave != -1:
            os.close(slave)


def device_json(arguments: list[str], output: Path, name: str) -> dict:
    target = output / f"{name}.json"
    run(["xcrun", "devicectl", *arguments, "--quiet", "--timeout", "30", "--json-output", str(target)],
        output / f"{name}.log", timeout=40)
    return json.loads(target.read_text())["result"]


def check_app(app: Path, udid: str) -> dict:
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != BUNDLE:
        raise ValueError(f"--app must be {BUNDLE}.")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    entitlements = plistlib.loads(subprocess.check_output(
        ["codesign", "-d", "--entitlements", "-", "--xml", str(app)], stderr=subprocess.PIPE))
    profile = plistlib.loads(subprocess.check_output(
        ["security", "cms", "-D", "-i", str(app / "embedded.mobileprovision")], stderr=subprocess.PIPE))
    if entitlements.get("get-task-allow") is not True or profile["Entitlements"].get("get-task-allow") is not True:
        raise ValueError("Distribution/TestFlight apps cannot be profiled; supply a development-signed Release app.")
    if udid not in profile.get("ProvisionedDevices", []) or profile["ExpirationDate"] <= dt.datetime.now(dt.timezone.utc).replace(tzinfo=None):
        raise ValueError("Development profile is expired or does not include the selected iPhone.")
    return {"bundleVersion": info["CFBundleVersion"], "signing": "development"}


def validate_trace(toc: Path, samples: Path, udid: str, duration: int) -> dict:
    runs = ET.parse(toc).getroot().findall("run")
    if len(runs) != 1:
        raise ValueError("Expected exactly one recorded run.")
    run_info = runs[0]
    target = run_info.find("info/target")
    summary = run_info.find("info/summary")
    if target is None or summary is None:
        raise ValueError("Trace has no target or summary.")
    device, process = target.find("device"), target.find("process")
    if device is None or device.get("uuid") != udid or device.get("platform") != "iOS":
        raise ValueError("Trace targets the wrong device.")
    if process is None or process.get("name") != "Trinket" or process.get("type") != "launched":
        raise ValueError("Trace does not target the launched Trinket process.")
    if process.get("return-exit-status") != "0":
        raise ValueError("Trinket did not exit normally during the recording.")
    elapsed = float(summary.findtext("duration", "nan"))
    if summary.findtext("end-reason") != "Time limit reached" or not math.isfinite(elapsed) or elapsed < duration:
        raise ValueError("Incomplete recording: time limit was not reached. A saved trace is not sufficient.")
    tables = run_info.findall("data/table")
    counts = dict.fromkeys(SCHEMAS, 0)
    node, schema = None, None
    # Long CPU recordings can export hundreds of thousands of backtraces.
    # Count rows without retaining their frames or even empty row elements.
    for event, element in ET.iterparse(samples, events=("start", "end")):
        if event == "start" and element.tag == "node":
            node, schema = element, None
            match = re.fullmatch(r"//trace-toc\[1\]/run\[1\]/data\[1\]/table\[(\d+)\]", element.get("xpath", ""))
            if match and 0 < int(match[1]) <= len(tables):
                schema = tables[int(match[1]) - 1].get("schema")
        elif event == "end" and element.tag == "row" and node is not None:
            if schema in counts:
                counts[schema] += 1
            node.remove(element)
            element.clear()
        elif event == "end" and element.tag == "node":
            node, schema = None, None
            element.clear()
    if not all(counts.values()):
        raise ValueError(f"Recording is missing CPU or frame measurements: {counts}.")
    return {"durationSeconds": elapsed, "endReason": summary.findtext("end-reason"),
            "process": process.attrib, "rowCounts": counts}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", help="Paired physical UDID, identifier or name; required if multiple are paired")
    parser.add_argument("--duration", type=int, default=30, help="Recording seconds (5–600; default 30)")
    parser.add_argument("--startup-timeout", type=int, default=120, help="Seconds allowed for recording to start")
    parser.add_argument("--output", type=Path, help="New evidence directory; existing paths are never overwritten")
    install = parser.add_mutually_exclusive_group()
    install.add_argument("--build", action="store_true", help="Build/install an optimized development app first")
    install.add_argument("--app", type=Path, help="Install an existing development-signed Release .app first")
    args = parser.parse_args()
    if not 5 <= args.duration <= 600 or args.startup_timeout < 1:
        parser.error("--duration must be 5–600 and --startup-timeout must be positive")
    output = (args.output or ROOT / ".DerivedData/PerformanceResults" / dt.datetime.now(dt.timezone.utc).strftime("device-%Y%m%dT%H%M%S.%fZ")).resolve()
    try:
        output.mkdir(parents=True, exist_ok=False)
    except OSError as error:
        parser.error(f"Cannot create a new evidence directory: {error}")
    def cancel(_signum, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, cancel)
    report = {"status": "failed", "bundleIdentifier": BUNDLE}
    try:
        developer = os.environ.get("DEVELOPER_DIR") or subprocess.check_output(
            ["xcode-select", "-p"], text=True).strip()
        os.environ["DEVELOPER_DIR"] = developer
        report["developerDirectory"] = developer
        devices = device_json(["list", "devices"], output, "devices")["devices"]
        device = select_device(devices, args.device)
        udid = device.get("properties", {}).get("hardware", device.get("hardwareProperties", {}))["udid"]
        common = Path(subprocess.check_output(["git", "rev-parse", "--git-common-dir"], cwd=ROOT, text=True).strip())
        with (ROOT / common / f"profile-device-{udid}.lock").open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as error:
                raise RuntimeError("Another profiling run owns this iPhone; wait for it to finish.") from error
            details = device_json(["device", "info", "details", "--device", udid], output, "device")
            props = details["properties"]
            if props["connection"]["state"] != "connected" or props["state"].get("developerModeStatus", {}).get("enabled", {}).get("mode") != 1:
                raise ValueError("Unlock the paired iPhone and enable Developer Mode before profiling.")
            report.update({"deviceUDID": udid, "transport": props["connection"]["transportType"],
                           "device": props["hardware"]["marketingName"], "software": props["software"]})
            app = args.app.resolve() if args.app else None
            if args.build:
                run([str(ROOT / "Scripts/install-device.sh"), "--device", udid, "--release", "--no-launch"],
                    output / "build.log", timeout=None)
                app = ROOT / ".DerivedData/Device/Build/Products/Release-iphoneos/Trinket.app"
            if app:
                report["app"] = check_app(app, udid)
                if not args.build:
                    run(["xcrun", "devicectl", "device", "install", "app", "--device", udid,
                         "--timeout", "300", str(app)], output / "install.log", timeout=310)
            apps = device_json(["device", "info", "apps", "--device", udid, "--bundle-id", BUNDLE], output, "app")["apps"]
            if len(apps) != 1 or apps[0].get("builtByDeveloper") is not True:
                raise ValueError("Install an optimized development app with --build or --app first.")
            report["installedApp"] = apps[0]
            report["buildConfiguration"] = "Release" if args.build else "Not verified; supplied or installed app"
            # Apple owns cache completeness and OS/model/architecture matching.
            run(["xcodebuild", "-prepareDeviceSupport", "-destination", f"id={udid}"],
                output / "symbols.log", timeout=1800)
            ddi = device_json(["device", "info", "ddiServices", "--device", udid], output, "ddi")["ddiMetadata"]
            if ddi.get("isUsable") is not True or ddi.get("contentIsCompatible") is not True:
                raise ValueError("Xcode's device support is incompatible; prepare/update the selected Xcode first.")
            run(["xcodebuild", "-version"], output / "xcode.log")
            print("Recording begins shortly. Reproduce the player interaction on the iPhone.", flush=True)
            trace = output / "recording.trace"
            run(["xcrun", "xctrace", "record", "--device", udid, "--instrument", "Time Profiler",
                 "--instrument", "Hitches", "--time-limit", f"{args.duration}s", "--no-prompt",
                 "--output", str(trace), "--launch", "--", BUNDLE], output / "recording.log",
                duration=args.duration, startup=args.startup_timeout)
            toc, samples = output / "toc.xml", output / "samples.xml"
            run(["xcrun", "xctrace", "export", "--input", str(trace), "--toc", "--output", str(toc)], output / "export-toc.log", timeout=None)
            xpath = '/trace-toc/run[@number="1"]/data/table[@schema="time-profile" or @schema="hitches-frame-lifetimes"]'
            run(["xcrun", "xctrace", "export", "--input", str(trace), "--xpath", xpath, "--output", str(samples)], output / "export-samples.log", timeout=None)
            report.update(validate_trace(toc, samples, udid, args.duration))
            report["status"] = "passed"
            print(f"Verified CPU and frame measurements: {report['rowCounts']}\nEvidence: {output}")
    except (ValueError, RuntimeError, OSError, KeyError, ET.ParseError, subprocess.SubprocessError) as error:
        report["error"] = str(error)
        print(f"Profiling failed: {error}\nDiagnostics: {output}", file=sys.stderr)
    except KeyboardInterrupt:
        report["error"] = "Cancelled; partial evidence retained."
        print(f"Cancelled. Diagnostics: {output}", file=sys.stderr)
    finally:
        (output / "result.json").write_text(json.dumps(report, indent=2) + "\n")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
