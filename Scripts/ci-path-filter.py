#!/usr/bin/env python3
"""CI path filter against the GitHub compare API (no full checkout).

Push workflows cannot use dorny/paths-filter REST mode (that is PR-only).
This script lists files via compare/{before}...{sha} and writes GITHUB_OUTPUT.
"""

from __future__ import annotations

import fnmatch
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

Z40 = "0000000000000000000000000000000000000000"

CODE_INCLUDES = (
    "Trinket/**",
    "Packages/**",
    "TrinketUITests/**",
    "ContentManifest/**",
    "ArtManifest/**",
    "MusicManifest/**",
    "SoundManifest/**",
    "CinematicManifest/**",
    "Raw Assets/**",
    "project.yml",
    "Trinket.xcodeproj/**",
    "*.xctestplan",
)
# Build/test/generate scripts must still run macos jobs; lint/CI glue stays infra.
CODE_SCRIPT_INCLUDES = (
    "Scripts/build.sh",
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
    "Scripts/ci-path-filter.py",
    "Scripts/lib/**",
)
CODE_EXCLUDES: tuple[str, ...] = ()
INFRA_INCLUDES = (
    "Scripts/**",
    ".github/actions/**",
    ".github/workflows/**",
    ".swiftlint.yml",
    ".swiftformat",
    "cliff.toml",
)
INFRA_EXCLUDES = ("Scripts/**/*.md",)
ASSET_INCLUDES = (
    "ArtManifest/**",
    "MusicManifest/**",
    "SoundManifest/**",
    "CinematicManifest/**",
    "Raw Assets/**",
    "Scripts/prepare-*.sh",
)


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
    return matches_any(path, CODE_INCLUDES) or matches_any(path, CODE_SCRIPT_INCLUDES)


def is_infra_path(path: str) -> bool:
    return matches_any(path, INFRA_INCLUDES) and not matches_any(path, INFRA_EXCLUDES)


def is_asset_path(path: str) -> bool:
    return matches_any(path, ASSET_INCLUDES)


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
    names: list[str] = []
    truncated = False
    while url:
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
                link = response.headers.get("Link", "")
        except urllib.error.HTTPError as error:
            if error.code in {404, 422}:
                return None
            body = error.read().decode("utf-8", errors="replace")
            raise SystemExit(f"compare API failed ({error.code}): {body}") from error
        truncated = truncated or bool(payload.get("truncated"))
        for entry in payload.get("files") or []:
            name = entry.get("filename")
            if name:
                names.append(name)
        url = ""
        for part in link.split(","):
            if 'rel="next"' in part:
                url = part.split(";")[0].strip().strip("<>")
                break
    if truncated:
        return None
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
