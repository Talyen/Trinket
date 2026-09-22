#!/usr/bin/env python3
"""CI path filter against the GitHub compare API (no full checkout).

Push workflows cannot use dorny/paths-filter REST mode (that is PR-only).
This script lists files via compare/{before}...{sha} and writes GITHUB_OUTPUT.
"""

from __future__ import annotations

import fnmatch
import functools
import json
import os
import shlex
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def _standalone_read_env_arrays(path: Path | str, names: list[str]) -> dict[str, tuple[str, ...]]:
    """Fallback for `internal.cli.read_env_arrays` when this file runs standalone.

    The changes workflow fetches only this file plus build-inputs.env into
    /tmp (no checkout by design), so the `internal` package is unavailable
    there. This mirrors the canonical parser's contract — shlex splitting,
    rejection of live shell expansions, and ValueError on unterminated or
    missing arrays — and Scripts/Tests/test_ci_path_filter.py pins the two
    implementations against each other.
    """
    wanted = set(names)
    found: dict[str, list[str]] = {}
    current: str | None = None
    buffer: list[str] = []
    for raw_line in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if current is None:
            for name in wanted:
                if line == f"{name}=(" or line.startswith(f"{name}=("):
                    rest = line[len(name) + 2 :].strip()
                    current = name
                    buffer = []
                    if rest:
                        line = rest
                    else:
                        break
                    if line.endswith(")"):
                        chunk = line[:-1].strip()
                        if chunk:
                            buffer.append(chunk)
                        found[current] = _standalone_split_array(" ".join(buffer), path, current)
                        current = None
                    elif line:
                        buffer.append(line)
                    break
        elif line.endswith(")"):
            chunk = line[:-1].strip()
            if chunk:
                buffer.append(chunk)
            assert current is not None
            found[current] = _standalone_split_array(" ".join(buffer), path, current)
            current = None
        else:
            buffer.append(line)
    if current is not None:
        raise ValueError(f"{path}: unterminated array {current}")
    missing = wanted - set(found)
    if missing:
        raise ValueError(f"{path}: missing arrays: {', '.join(sorted(missing))}")
    return {name: tuple(found[name]) for name in names}


def _standalone_split_array(body: str, path: Path | str, name: str) -> list[str]:
    if "$" in body or "`" in body:
        raise ValueError(f"{path}: array {name} needs live shell expansion; source it in bash instead")
    return shlex.split(body)


try:
    from internal.cli import read_env_arrays
except ImportError:
    read_env_arrays = _standalone_read_env_arrays

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
    "Scripts/build.sh",
    "Scripts/build-metadata.py",
    "Scripts/restore-ci-test-products.sh",
    "Scripts/build-*.sh",
    "Scripts/build-for-testing.sh",
    "Scripts/build-freshness.sh",
    "Scripts/test.sh",
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


def _inputs() -> tuple[tuple[str, ...], tuple[str, ...], tuple[str, ...]]:
    return generation_inputs()


def is_generation_input(path: str, inputs: tuple[str, ...]) -> bool:
    return any(glob_match(path, entry) or path.startswith(entry + "/") for entry in inputs)


def _match_segments(pattern_segments: list[str], path_segments: list[str]) -> bool:
    if not pattern_segments:
        return not path_segments
    head, rest = pattern_segments[0], pattern_segments[1:]
    if head == "**":
        if not rest:
            return len(path_segments) >= 1
        return any(
            _match_segments(rest, path_segments[index:])
            for index in range(len(path_segments) + 1)
        )
    if not path_segments:
        return False
    return fnmatch.fnmatchcase(path_segments[0], head) and _match_segments(
        rest, path_segments[1:]
    )


def glob_match(path: str, pattern: str) -> bool:
    return _match_segments(pattern.split("/"), path.split("/"))


def matches_any(path: str, patterns: tuple[str, ...]) -> bool:
    return any(glob_match(path, pattern) for pattern in patterns)


def is_code_path(path: str) -> bool:
    if matches_any(path, CODE_EXCLUDES):
        return False
    content_inputs, asset_inputs, project_inputs = _inputs()
    return (matches_any(path, CODE_INCLUDES) or matches_any(path, CODE_SCRIPT_INCLUDES)
            or is_generation_input(path, content_inputs + asset_inputs + project_inputs))


def is_infra_path(path: str) -> bool:
    return matches_any(path, INFRA_INCLUDES) and not matches_any(path, INFRA_EXCLUDES)


def is_asset_path(path: str) -> bool:
    _, asset_inputs, _ = _inputs()
    return not path.endswith(".md") and is_generation_input(path, asset_inputs)


def classify(paths: list[str]) -> tuple[bool, bool, bool]:
    return (
        any(is_code_path(p) for p in paths),
        any(is_asset_path(p) for p in paths),
        any(is_infra_path(p) for p in paths),
    )


def write_output(code: bool, assets: bool, infra: bool) -> None:
    payload = (
        f"code={'true' if code else 'false'}\n"
        f"assets={'true' if assets else 'false'}\n"
        f"infra={'true' if infra else 'false'}\n"
    )
    output_path = os.environ.get("GITHUB_OUTPUT")
    if output_path:
        with Path(output_path).open("a", encoding="utf-8") as handle:
            handle.write(payload)
    print(payload, end="")


def compare_filenames(repo: str, before: str, sha: str, token: str) -> list[str] | None:
    encoded = urllib.parse.quote(f"{before}...{sha}")
    url = f"https://api.github.com/repos/{repo}/compare/{encoded}?per_page=100"
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "trinket-ci-path-filter",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        if error.code in {404, 422}:
            return None
        body = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"compare API failed ({error.code}): {body}") from error
    files = payload.get("files") or []
    # Compare pagination only pages commits; files stop at 300 on page one.
    if payload.get("truncated") or len(files) >= 300:
        return None
    names: list[str] = []
    for entry in files:
        for key in ("filename", "previous_filename"):
            name = entry.get(key)
            if name:
                names.append(name)
    return names


def main() -> None:
    event_name = os.environ.get("EVENT_NAME") or os.environ.get("GITHUB_EVENT_NAME", "")
    if event_name == "workflow_dispatch":
        print("workflow_dispatch: treating code, assets, and infra as changed.")
        write_output(True, True, True)
        return

    before = os.environ.get("BEFORE") or os.environ.get("GITHUB_EVENT_BEFORE", "")
    sha = os.environ.get("SHA") or os.environ.get("GITHUB_SHA", "")
    if not sha or before in ("", Z40):
        print("No previous commit; treating code, assets, and infra as changed.")
        write_output(True, True, True)
        return

    repo = os.environ.get("GITHUB_REPOSITORY", "")
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or ""
    if not repo or not token:
        raise SystemExit("GITHUB_REPOSITORY and GH_TOKEN/GITHUB_TOKEN are required.")

    filenames = compare_filenames(repo, before, sha, token)
    if filenames is None:
        print("Compare result truncated; treating code, assets, and infra as changed.")
        write_output(True, True, True)
        return

    code, assets, infra = classify(filenames)
    print(f"Changed files: {len(filenames)}; code={code}; assets={assets}; infra={infra}")
    write_output(code, assets, infra)


if __name__ == "__main__":
    main()
