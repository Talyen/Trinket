#!/usr/bin/env python3
"""Generate App Store / TestFlight release notes from git history."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "ReleaseNotes" / "en-US.txt"

KEEP_TYPES = ("feat", "fix", "content", "perf")
SKIP_TYPES = ("refactor", "style", "chore", "ci", "docs", "build", "test")
SKIP_VERBS = ("extract", "thin", "split", "wire", "rename", "refactor")
CONVENTIONAL_TYPE = re.compile(
    r"^(feat|fix|perf|refactor|content|style|test|ci|chore|docs|build)"
    r"(\([^)]+\))?!?:\s*",
    re.IGNORECASE,
)
SKIP_VERB_PREFIX = re.compile(
    rf"^({'|'.join(SKIP_VERBS)})\b",
    re.IGNORECASE,
)
USER_FACING_TRAILER = re.compile(
    r"^User-Facing:\s*(yes|no)\s*$",
    re.MULTILINE | re.IGNORECASE,
)
UNRELEASED_PLACEHOLDER = re.compile(
    r"\n## \[Unreleased\]\s*(?:<!--[^\n]*-->\s*)?",
)
INFRA_PREFIXES = (
    "Scripts/",
    "Docs/",
    ".github/",
    ".githooks/",
    ".agents/",
    "TrinketUITests/",
    "Trinket.xcodeproj/",
    "ReleaseNotes/",
)
INFRA_NAMES = {
    ".swiftlint.yml",
    ".swiftformat",
    ".gitignore",
    "cliff.toml",
    "CHANGELOG.md",
    "project.yml",
    "AGENTS.md",
    "FullUI.xctestplan",
}
PRODUCT_PREFIXES = (
    "Trinket/",
    "Packages/",
    "ContentManifest/",
    "ArtManifest/",
    "MusicManifest/",
    "SoundManifest/",
    "CinematicManifest/",
    "Raw Assets/",
)
TECHNICAL_TERMS = (
    "SwiftFormat",
    "SwiftLint",
    "XcodeGen",
    "CloudKit",
    "UserDefaults",
    "fatalError",
    "assertionFailure",
    "Sendable",
    "Codable",
    "xcodebuild",
    "DerivedData",
    "shebang",
    "CI ",
    " CI",
)


@dataclass(frozen=True)
class Commit:
    subject: str
    body: str = ""
    files: tuple[str, ...] = ()


def run(*args: str) -> str:
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, check=True)
    return result.stdout


def latest_tag() -> str | None:
    tags = run("git", "tag", "-l", "v[0-9]*", "--sort=-v:refname").splitlines()
    return tags[0] if tags else None


def strip_unreleased_section(text: str) -> str:
    return UNRELEASED_PLACEHOLDER.sub("\n", text, count=1)


def conventional_type(subject: str) -> str | None:
    match = CONVENTIONAL_TYPE.match(subject)
    return match.group(1).lower() if match else None


def is_infra_path(path: str) -> bool:
    if path in INFRA_NAMES or path.endswith(".md") or path.endswith(".xctestplan"):
        return True
    if path.endswith("Package.swift") or "TrinketTestSupport" in path:
        return True
    if "/Tests/" in path or path.endswith("Tests.swift"):
        return True
    return path.startswith(INFRA_PREFIXES)


def is_product_path(path: str) -> bool:
    return not is_infra_path(path) and path.startswith(PRODUCT_PREFIXES)


def is_infra_only(files: tuple[str, ...]) -> bool:
    return bool(files) and all(is_infra_path(path) for path in files)


def has_product_path(files: tuple[str, ...]) -> bool:
    return any(is_product_path(path) for path in files)


def user_facing_trailer(body: str) -> str | None:
    match = USER_FACING_TRAILER.search(body)
    return match.group(1).lower() if match else None


def is_user_facing(commit: Commit) -> bool:
    subject = commit.subject.strip()
    if subject.startswith(("Merge ", "Revert ")):
        return False
    trailer = user_facing_trailer(commit.body)
    if trailer == "no":
        return False
    if trailer == "yes":
        return True
    if is_infra_only(commit.files):
        return False
    commit_type = conventional_type(subject)
    if commit_type in SKIP_TYPES:
        return False
    if commit_type in KEEP_TYPES:
        return True
    if SKIP_VERB_PREFIX.match(subject):
        return False
    return has_product_path(commit.files)


def simplify_line(line: str) -> str:
    line = re.sub(r"`([^`]+)`", r"\1", line)
    line = re.sub(r"\s+", " ", line).strip(" -•\t")
    for term in TECHNICAL_TERMS:
        if term in line:
            return ""
    return line


def capitalize_line(line: str) -> str:
    if not line:
        return ""
    if not line[0].isupper():
        return line[0].upper() + line[1:]
    return line


def subject_to_user_line(subject: str) -> str:
    line = CONVENTIONAL_TYPE.sub("", subject, count=1)
    return capitalize_line(simplify_line(line))


def extract_bullets(body: str) -> list[str]:
    bullets: list[str] = []
    for raw in body.splitlines():
        raw = raw.strip()
        if not raw.startswith("- "):
            continue
        cleaned = simplify_line(raw[2:])
        if cleaned and not cleaned.lower().startswith(("co-authored-by", "user-facing:")):
            bullets.append(cleaned)
    return bullets


def player_line(commit: Commit) -> str:
    for bullet in extract_bullets(commit.body):
        line = capitalize_line(bullet)
        if line:
            return line
    return subject_to_user_line(commit.subject)


def build_notes(commits: list[Commit], version: str = "") -> tuple[str, list[str]]:
    del version
    lines: list[str] = []
    for commit in commits:
        if not is_user_facing(commit):
            continue
        line = player_line(commit)
        if line and line not in lines:
            lines.append(line)

    if not lines:
        return "Bug fixes and improvements.", ["• Stability and performance improvements"]

    summary = lines[0]
    if len(summary) > 150:
        summary = summary[:147].rstrip() + "..."

    bullets = [f"• {item}" for item in lines[:6]]
    return summary, bullets


def validate_notes(summary: str, bullets: list[str]) -> None:
    full = summary + "\n\n" + "\n".join(bullets)
    if len(full) > 4000:
        raise SystemExit(f"Release notes exceed 4000 characters ({len(full)}). Trim before shipping.")
    if len(summary) > 150:
        print(f"Warning: summary line is {len(summary)} chars (App Store truncates around 150).", file=sys.stderr)


def parse_git_log(raw: str) -> list[Commit]:
    commits: list[Commit] = []
    for block in raw.split("===COMMIT===\n"):
        block = block.strip("\n")
        if not block:
            continue
        if "\n===BODY===\n" not in block or "\n===FILES===" not in block:
            continue
        subject_part, rest = block.split("\n===BODY===\n", 1)
        body_part, files_part = rest.split("\n===FILES===", 1)
        files = tuple(path.strip() for path in files_part.splitlines() if path.strip())
        commits.append(
            Commit(subject=subject_part.strip(), body=body_part.strip(), files=files)
        )
    return commits


def load_commits(since_tag: str | None) -> list[Commit]:
    log_range = f"{since_tag}..HEAD" if since_tag else "HEAD"
    raw = run(
        "git",
        "log",
        log_range,
        "--pretty=format:===COMMIT===%n%s%n===BODY===%n%b%n===FILES===",
        "--name-only",
        "--no-merges",
    )
    return parse_git_log(raw)


def format_notes(summary: str, bullets: list[str]) -> str:
    return summary + "\n\n" + "\n".join(bullets) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate App Store release notes.")
    parser.add_argument("--version", help="Release version (e.g. 0.2.0)")
    parser.add_argument("--since-tag", help="Git tag to start from (default: latest v* tag)")
    parser.add_argument("--dry-run", action="store_true", help="Print to stdout only")
    parser.add_argument(
        "--strip-unreleased",
        metavar="CHANGELOG",
        help="Remove leftover Unreleased placeholder from a changelog file",
    )
    args = parser.parse_args()

    if args.strip_unreleased:
        path = Path(args.strip_unreleased)
        original = path.read_text(encoding="utf-8")
        updated = strip_unreleased_section(original)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
        return

    since = args.since_tag or latest_tag()
    commits = load_commits(since)
    summary, bullets = build_notes(commits, args.version or "unreleased")
    validate_notes(summary, bullets)
    content = format_notes(summary, bullets)

    if args.dry_run:
        print(content, end="")
        return

    OUTPUT.write_text(content, encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
