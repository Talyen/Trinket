#!/usr/bin/env python3
"""Record and validate the environment that produced reusable test binaries."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile


def capture(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=30).strip()


def identity(sdk="iphonesimulator", configuration="Debug"):
    ci = os.environ.get("CI") == "true" or os.environ.get("GITHUB_ACTIONS") == "true"
    try:
        commit = capture("git", "rev-parse", "HEAD")
    except subprocess.CalledProcessError:
        if ci:
            raise
        commit = None
    return {
        "version": 1,
        "xcode": capture("xcodebuild", "-version"),
        "sdk": sdk,
        "sdk_version": capture("xcrun", "--sdk", sdk, "--show-sdk-version"),
        "sdk_build": capture("xcrun", "--sdk", sdk, "--show-sdk-build-version"),
        "host_architecture": platform.machine(),
        "configuration": configuration,
        "architecture_policy": "sdk-default" if ci else "host",
        "commit": commit,
    }


def stamp_path(results, fingerprint):
    key = hashlib.sha256(fingerprint.encode()).hexdigest()
    return results / f".last-build-{key}.stamp"


def group(fingerprint):
    return fingerprint if isinstance(fingerprint, str) and fingerprint.startswith("package_") else "app"


def differences(saved, current):
    keys = set(current)
    if os.environ.get("CI") != "true" and os.environ.get("GITHUB_ACTIONS") != "true":
        keys.remove("commit")  # Local source freshness remains owned by build-freshness.sh.
    return sorted(key for key in keys if saved.get(key) != current[key])


def read_metadata(path):
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"Invalid metadata: {path}")
    return value


def invalidate(results, product_group):
    for path in results.glob(".last-build-*.stamp.json"):
        try:
            saved = read_metadata(path)
        except (OSError, ValueError):
            continue  # Invalid/legacy metadata is already unusable.
        if group(saved.get("fingerprint", "")) == product_group:
            stamp = path.with_suffix("")
            for target in (stamp, path, Path(f"{stamp}.gitstatus")):
                target.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("begin", "write", "check", "invalidate"))
    parser.add_argument("results", type=Path)
    parser.add_argument("fingerprint")
    parser.add_argument("--started", help="Identity captured before building")
    parser.add_argument("--sdk", default="iphonesimulator")
    parser.add_argument("--configuration", default="Debug")
    args = parser.parse_args()
    if args.action == "invalidate":
        invalidate(args.results, group(args.fingerprint))
        return
    current = identity(args.sdk, args.configuration)
    stamp = stamp_path(args.results, args.fingerprint)
    metadata = Path(f"{stamp}.json")
    if args.action == "begin":
        invalidate(args.results, group(args.fingerprint))
        print(json.dumps(current, sort_keys=True))
    elif args.action == "write":
        if not args.started or differences(json.loads(args.started), current):
            raise ValueError("Build environment changed during compilation; rebuild before reuse.")
        current["fingerprint"] = args.fingerprint
        args.results.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", dir=args.results, delete=False) as handle:
            json.dump(current, handle, sort_keys=True)
            temporary = Path(handle.name)
        try:
            temporary.replace(metadata)
        finally:
            temporary.unlink(missing_ok=True)
    else:
        if not stamp.is_file():
            raise ValueError(f"Missing build stamp for {args.fingerprint}; rebuild before reuse.")
        saved = read_metadata(metadata)
        changed = differences(saved, current)
        if saved.get("fingerprint") != args.fingerprint:
            changed.append("fingerprint")
        if changed:
            raise ValueError(f"Build metadata mismatch ({', '.join(changed)}); rebuild before reuse.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Build reuse refused: {error}", file=sys.stderr)
        sys.exit(1)
