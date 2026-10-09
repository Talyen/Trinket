#!/usr/bin/env python3
"""CI path filter against the GitHub compare API (no full checkout).

Push workflows cannot use dorny/paths-filter REST mode (that is PR-only).
This script lists files via compare/{before}...{sha} and writes GITHUB_OUTPUT.
"""

from __future__ import annotations

import fnmatch
import base64
import hashlib
from collections.abc import Callable
import re
import functools
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


from internal.cli import read_env_arrays

Z40 = "0000000000000000000000000000000000000000"

CODE_INCLUDES = (
    "Trinket/**",
    "Packages/**",
    "TrinketUITests/**",
    "project.yml",
    "Trinket.xcodeproj/**",
    "*.xctestplan",
)
# Build/test/generate scripts must still run macos jobs; lint/CI glue stays infra.
CODE_SCRIPT_INCLUDES = (
    "Scripts/setup-ci-xcode.py",
    "Scripts/config/ci-xcode.json",
    "Scripts/build.sh",
    "Scripts/build-metadata.py",
    "Scripts/restore-ci-test-products.sh",
    "Scripts/build-*.sh",
    "Scripts/build-for-testing.sh",
    "Scripts/build-freshness.sh",
    "Scripts/test.sh",
    "Scripts/phase-timing.py",
    "Scripts/ci_ui_retry.py",
    ".github/actions/package-cache/**",
    "Scripts/test-*.sh",
    "Scripts/generate.sh",
    "Scripts/ensure-simulator.sh",
    "Scripts/stage-ci-*.sh",
    "Scripts/prune-*.sh",
    "Scripts/run-env.sh",
    "Scripts/xcode-runner.sh",
    "Scripts/ci-path-filter.py",
    "Scripts/lib/**",
    ".github/actions/setup-trinket/**",
    ".github/actions/checkout-trinket/**",
    ".github/actions/restore-and-build/**",
    ".github/actions/build-cache-key/**",
    ".github/actions/test-job/**",
    ".github/workflows/tests.yml",
    ".github/workflows/ci.yml",
)
CODE_EXCLUDES = ("**/*.md",)
INFRA_INCLUDES = (
    "Scripts/**",
    ".githooks/**",
    ".github/actions/**",
    ".github/workflows/**",
    ".swiftlint.yml",
    ".swiftformat",
    "cliff.toml",
)
INFRA_EXCLUDES = ("Scripts/**/*.md",)


@functools.cache
def generation_inputs() -> tuple[tuple[str, ...], ...]:
    """Generation input registries parsed from build-inputs.env in Python.

    Lazy (not import-time) so importing this module never shells out, and
    parsed — not bash-sourced — so behavior is identical without a subprocess.
    """
    registry = Path(__file__).with_name("build-inputs.env")
    parsed = read_env_arrays(
        registry,
        [
            "TRINKET_CONTENT_GENERATION_INPUTS",
            "TRINKET_ASSET_GENERATION_INPUTS",
            "TRINKET_PROJECT_GENERATION_INPUTS",
        ],
    )
    return (
        parsed["TRINKET_CONTENT_GENERATION_INPUTS"],
        parsed["TRINKET_ASSET_GENERATION_INPUTS"],
        parsed["TRINKET_PROJECT_GENERATION_INPUTS"],
    )


def is_generation_input(path: str, inputs: tuple[str, ...]) -> bool:
    return any(glob_match(path, entry) or path.startswith(entry + "/") for entry in inputs)


def glob_match(path: str, pattern: str) -> bool:
    patterns, segments = pattern.split("/"), path.split("/")

    @functools.cache
    def match(p: int, s: int) -> bool:
        if p == len(patterns):
            return s == len(segments)
        if patterns[p] == "**":
            if p == len(patterns) - 1:
                return s < len(segments)
            return match(p + 1, s) or (s < len(segments) and match(p, s + 1))
        return s < len(segments) and fnmatch.fnmatchcase(segments[s], patterns[p]) and match(p + 1, s + 1)

    return match(0, 0)


def matches_any(path: str, patterns: tuple[str, ...]) -> bool:
    return any(glob_match(path, pattern) for pattern in patterns)


def is_code_path(path: str) -> bool:
    if matches_any(path, CODE_EXCLUDES):
        return False
    content_inputs, asset_inputs, project_inputs = generation_inputs()
    return (matches_any(path, CODE_INCLUDES) or matches_any(path, CODE_SCRIPT_INCLUDES)
            or is_generation_input(path, content_inputs + asset_inputs + project_inputs))


SMOKE_INCLUDES = (
    "Scripts/setup-ci-xcode.py",
    "Scripts/config/ci-xcode.json",
    "Trinket/**",
    "TrinketUITests/**",
    "Packages/TrinketBattleFeature/**",
    "Packages/TrinketFeatureSupport/**",
    "Packages/TrinketDesignSystem/**",
    "StoreKit/**",
    "project.yml",
    "Smoke.xctestplan",
    "FullUI.xctestplan",
    "Scripts/build-for-testing.sh",
    "Scripts/test.sh",
    "Scripts/ensure-simulator.sh",
    "Scripts/run-env.sh",
    "Scripts/xcode-runner.sh",
    "Scripts/ci-path-filter.py",
    "Scripts/lib/app-build.sh",
    "Scripts/lib/simctl.sh",
    "Scripts/lib/slots.sh",
    ".github/actions/setup-trinket/**",
    ".github/actions/checkout-trinket/**",
    ".github/actions/restore-and-build/**",
    ".github/actions/test-job/**",
    ".github/workflows/tests.yml",
    ".github/workflows/ci.yml",
)
SMOKE_EXCLUDES = ("**/*.md",)


def is_infra_path(path: str) -> bool:
    return matches_any(path, INFRA_INCLUDES) and not matches_any(path, INFRA_EXCLUDES)


def is_smoke_path(path: str) -> bool:
    if matches_any(path, SMOKE_EXCLUDES):
        return False
    return matches_any(path, SMOKE_INCLUDES)


@functools.cache
def asset_outputs() -> tuple[str, ...]:
    registry = Path(__file__).with_name('config') / 'generated-paths.tsv'
    return tuple(line.partition('|')[2].rstrip('/') for line in registry.read_text().splitlines()
                 if line.startswith('asset|'))


def is_asset_path(path: str) -> bool:
    _, asset_inputs, _ = generation_inputs()
    return not path.endswith(".md") and is_generation_input(path, asset_inputs + asset_outputs())


def classify(paths: list[str]) -> tuple[bool, bool, bool]:
    return (
        any(is_code_path(p) for p in paths),
        any(is_asset_path(p) for p in paths),
        any(is_infra_path(p) for p in paths),
    )


def needs_smoke(paths: list[str]) -> bool:
    return any(is_smoke_path(p) for p in paths)


SHARDS = {
    "Engine": ["BattleEngine"],
    "State": ["TrinketCore", "TrinketPersistence", "TrinketAppState"],
    "Content": ["TrinketContent", "TrinketDesignSystem"],
    "Battle": ["TrinketFeatureSupport", "TrinketBattleFeature"],
}

# Reviewed static layouts keep Tests private and shared support under Sources.
# Update only after reviewing target/input ownership; never refresh automatically.
REVIEWED_MANIFESTS = {
    "BattleEngine": "3ec585663958b4c2352fd58f9439d7f64efb510587d54307790aeb761cb58e34",
    "TrinketAppState": "a718bfff07a2e0421daacebfb96502e7c9c1e1049d5e5b03b0bcd82f58b1a8e5",
    "TrinketBattleFeature": "31b3930d5d631029c1b4ca082f118fbd60bd760f639402b1295bf4c2dc393576",
    "TrinketContent": "0fad35c1e4a5c26490417c0eb9fd224c40b59f4c71747e6600052367d8ba8d9c",
    "TrinketCore": "a65853629752a8ef2be3b782af81a98e157611d5cc28952b5833233198d992cf",
    "TrinketDesignSystem": "a3e8ebd730bb083e90bb032641d0cd5029aea715d63fec4840566169e11944bb",
    "TrinketFeatureSupport": "1e9f3c2d60429248367f3da19cad4354875741476d790ff88564b15ce73d4687",
    "TrinketPersistence": "66ea7e8ea805f9b686ed97baa802b06b66243c3b09b4e9e3c59a7aedbba4bce1",
}


def all_packages() -> set[str]:
    return {package for packages in SHARDS.values() for package in packages}


def affected_packages(paths: list[str], load_dependencies: Callable[[], dict[str, set[str]]]) -> set[str]:
    owners = all_packages()
    selected = set()
    changed_sources = set()
    for path in paths:
        if path.endswith(".md"):
            continue
        if path.startswith("TrinketUITests/") or path.endswith(".xctestplan"):
            continue
        if path.startswith("Packages/"):
            parts = path.split("/")
            if len(parts) < 3 or parts[1] not in owners or parts[-1] == "Package.swift":
                return owners
            selected.add(parts[1])
            # Test targets are private to their package. Shared test support
            # lives under Sources and still invalidates dependent packages.
            if len(parts) < 4 or parts[2] != "Tests":
                changed_sources.add(parts[1])
        elif is_code_path(path):
            return owners
    if not selected or selected == owners:
        return selected
    dependencies = load_dependencies()
    if set(dependencies) != owners or any(not deps <= owners for deps in dependencies.values()):
        return owners
    while True:
        expanded = changed_sources | {owner for owner, deps in dependencies.items() if deps & changed_sources}
        if expanded == changed_sources:
            return selected | expanded
        changed_sources = expanded


def package_matrix(selected: set[str]) -> dict:
    entries = [{"name": name, "packages": " ".join(p for p in packages if p in selected)}
               for name, packages in SHARDS.items() if any(p in selected for p in packages)]
    # GitHub validates matrices even for skipped jobs; keep an inert nonempty
    # matrix while the independent units output prevents its execution.
    return {"include": entries or [{"name": "Engine", "packages": "BattleEngine"}]}


def dependency_graph(repo: str, sha: str, token: str) -> dict[str, set[str]]:
    graph = {}
    for package in all_packages():
        url = f"https://api.github.com/repos/{repo}/contents/Packages/{package}/Package.swift?ref={sha}"
        data = github_json(url, token)
        if not isinstance(data.get("content"), str):
            raise ValueError(f"Missing dependency manifest content in {package}")
        manifest = base64.b64decode(data["content"])
        if hashlib.sha256(manifest).hexdigest() != REVIEWED_MANIFESTS.get(package):
            raise ValueError(f"Unreviewed target layout in {package}")
        source = manifest.decode("utf-8")
        # These packages use repository-relative local dependencies. Unknown
        # package forms force the full portfolio rather than guessing ownership.
        paths = re.findall(r'\.package\(path:\s*"\.\./([^"/]+)"\)', source)
        if len(paths) != len(re.findall(r'\.package\(', source)):
            raise ValueError(f"Unsupported dependency declaration in {package}")
        graph[package] = set(paths)
    return graph


def write_output(code: bool, assets: bool, infra: bool, smoke: bool = False, packages: set[str] | None = None) -> None:
    payload = (
        f"code={'true' if code else 'false'}\n"
        f"assets={'true' if assets else 'false'}\n"
        f"infra={'true' if infra else 'false'}\n"
        f"smoke={'true' if smoke else 'false'}\n"
    )
    selected = all_packages() if packages is None else packages
    payload += f"units={'true' if selected else 'false'}\n"
    payload += "unit-matrix=" + json.dumps(package_matrix(selected), separators=(",", ":")) + "\n"
    output_path = os.environ.get("GITHUB_OUTPUT")
    if output_path:
        with Path(output_path).open("a", encoding="utf-8") as handle:
            handle.write(payload)
    print(payload, end="")


def github_json(url: str, token: str, *, timeout: int = 30) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "trinket-ci-path-filter",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.load(response)
    if not isinstance(payload, dict):
        raise ValueError("GitHub response must be an object")
    return payload


def compare_filenames(repo: str, before: str, sha: str, token: str) -> list[str] | None:
    encoded = urllib.parse.quote(f"{before}...{sha}")
    url = f"https://api.github.com/repos/{repo}/compare/{encoded}?per_page=100"
    try:
        payload = github_json(url, token, timeout=60)
    except urllib.error.HTTPError as error:
        if error.code in {404, 422}:
            return None
        body = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"compare API failed ({error.code}): {body}") from error
    except (OSError, ValueError):
        return None
    files = payload.get("files")
    # Compare pagination only pages commits; files stop at 300 on page one.
    if not isinstance(files, list) or payload.get("truncated") or len(files) >= 300:
        return None
    names: list[str] = []
    for entry in files:
        if not isinstance(entry, dict) or not isinstance(entry.get("filename"), str) or not entry["filename"]:
            return None
        if entry.get("status") == "renamed" and not entry.get("previous_filename"):
            return None
        for key in ("filename", "previous_filename"):
            name = entry.get(key)
            if name:
                if not isinstance(name, str):
                    return None
                names.append(name)
    return names


def main() -> None:
    event_name = os.environ.get("EVENT_NAME") or os.environ.get("GITHUB_EVENT_NAME", "")
    if event_name == "workflow_dispatch":
        print("workflow_dispatch: treating code, assets, infra, and smoke as changed.")
        write_output(True, True, True, True)
        return

    before = os.environ.get("BEFORE") or os.environ.get("GITHUB_EVENT_BEFORE", "")
    sha = os.environ.get("SHA") or os.environ.get("GITHUB_SHA", "")
    if not sha or before in ("", Z40):
        print("No previous commit; treating code, assets, infra, and smoke as changed.")
        write_output(True, True, True, True)
        return

    repo = os.environ.get("GITHUB_REPOSITORY", "")
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or ""
    if not repo or not token:
        raise SystemExit("GITHUB_REPOSITORY and GH_TOKEN/GITHUB_TOKEN are required.")

    filenames = compare_filenames(repo, before, sha, token)
    if filenames is None:
        print("Compare evidence incomplete; treating code, assets, infra, and smoke as changed.")
        write_output(True, True, True, True)
        return

    code, assets, infra = classify(filenames)
    smoke = needs_smoke(filenames)
    print(f"Changed files: {len(filenames)}; code={code}; assets={assets}; infra={infra}; smoke={smoke}")
    selected = all_packages()
    try:
        selected = affected_packages(filenames, lambda: dependency_graph(repo, sha, token))
    except (OSError, ValueError, KeyError, urllib.error.URLError):
        print("Dependency evidence unavailable; selecting all package suites.")
    write_output(code, assets, infra, smoke, selected)


if __name__ == "__main__":
    main()
