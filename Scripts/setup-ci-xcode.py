#!/usr/bin/env python3
"""Select the required CI toolchain and prove Metal can compile and link."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def installed_xcodes(directory: Path) -> list[tuple[Path, str, str]]:
    installations = {}
    for app in sorted(directory.glob("Xcode*.app")):
        app = app.resolve()
        if app in installations:
            continue
        try:
            with (app / "Contents/version.plist").open("rb") as source:
                version = plistlib.load(source)
            # Info.plist's DTXcodeBuild can differ from the actual product build.
            product_version, build = version["CFBundleShortVersionString"], version["ProductBuildVersion"]
            if not isinstance(product_version, str) or not re.fullmatch(r"\d+(?:\.\d+)*", product_version):
                continue
            if not isinstance(build, str) or not build:
                continue
            installations[app] = (app, product_version, build)
        except (OSError, ValueError, KeyError, TypeError):
            continue
    return list(installations.values())


def select_xcode(installations: list[tuple[Path, str, str]], channel: str,
                 approved: dict[str, str]) -> tuple[Path, str, str]:
    if channel == "verified":
        matches = [item for item in installations if item[1:] == (approved["version"], approved["build"])]
        if not matches:
            raise RuntimeError(f"Required Xcode {approved['version']} ({approved['build']}) is not installed; "
                               f"available: {[(version, build) for _, version, build in installations]}")
        return matches[0]
    if not installations:
        raise RuntimeError("No readable Xcode installation found")
    def order(item):
        return tuple(int(part) for part in item[1].split(".")), tuple(
            (0, int(part)) if part.isdigit() else (1, part) for part in re.findall(r"\d+|\D+", item[2])
        )
    return max(installations, key=order)


def metal_probe(environment: dict[str, str], directory: Path) -> bool:
    source = directory / "probe.metal"
    source.write_text("#include <metal_stdlib>\nusing namespace metal;\n"
                      "kernel void probe(device float *out [[buffer(0)]], uint id [[thread_position_in_grid]]) "
                      "{ out[id] = 1.0f; }\n")
    try:
        for arguments in (
            ["metal", "-c", str(source), "-o", str(directory / "probe.air")],
            ["metallib", str(directory / "probe.air"), "-o", str(directory / "probe.metallib")],
        ):
            result = subprocess.run(["xcrun", "--sdk", "iphonesimulator", *arguments],
                                    env=environment, timeout=30, check=False)
            if result.returncode:
                return False
        return (directory / "probe.metallib").is_file()
    except subprocess.TimeoutExpired:
        return False


def ensure_metal(environment: dict[str, str]) -> None:
    with tempfile.TemporaryDirectory(prefix="trinket-metal-") as temporary:
        directory = Path(temporary)
        if metal_probe(environment, directory):
            print("Metal compiler and linker are ready.", flush=True)
            return
        for attempt in range(3):
            if attempt:
                time.sleep((10, 30)[attempt - 1])
            print(f"Installing Metal toolchain (attempt {attempt + 1}/3).", flush=True)
            try:
                result = subprocess.run(
                    ["sudo", "env", f"DEVELOPER_DIR={environment['DEVELOPER_DIR']}",
                     "xcodebuild", "-downloadComponent", "MetalToolchain"],
                    env=environment, timeout=120, check=False,
                )
            except subprocess.TimeoutExpired:
                print("Metal download exceeded two minutes.", flush=True)
                continue
            if result.returncode == 0 and metal_probe(environment, directory):
                print("Metal compiler and linker are ready.", flush=True)
                return
        raise RuntimeError("Metal is unavailable for the selected Xcode after three attempts. "
                           "No app build or test verification has occurred; inspect the runner image and Apple catalog logs.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--channel", choices=("verified", "latest"), default="verified")
    parser.add_argument("--metal", action="store_true")
    args = parser.parse_args()
    approved = json.loads((ROOT / "Scripts/config/ci-xcode.json").read_text())
    app, version, build = select_xcode(installed_xcodes(Path("/Applications")), args.channel, approved)
    environment = {**os.environ, "DEVELOPER_DIR": str(app / "Contents/Developer")}
    print(f"Selecting Xcode: {app} ({version}, build {build}, channel {args.channel})", flush=True)
    subprocess.run(["xcodebuild", "-version"], env=environment, timeout=30, check=True)
    subprocess.run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"],
                   env=environment, timeout=30, check=True)
    if args.metal:
        ensure_metal(environment)
    with Path(os.environ["GITHUB_ENV"]).open("a") as output:
        for key, value in {"DEVELOPER_DIR": environment["DEVELOPER_DIR"], "XCODE_PATH": str(app),
                           "XCODE_VERSION": version, "XCODE_BUILD": build}.items():
            output.write(f"{key}={value}\n")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit(f"Xcode setup failed: {error}")
