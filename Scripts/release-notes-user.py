#!/usr/bin/env python3
"""Generate App Store / TestFlight release notes from git history."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "ReleaseNotes" / "en-US.txt"
PROMPT = ROOT / "ReleaseNotes" / ".prompt.md"
FASTLANE = ROOT / "fastlane" / "metadata" / "en-US" / "release_notes.txt"

SKIP_PREFIXES = (
    "style:",
    "style ",
    "test:",
    "ci:",
    "chore:",
    "docs:",
    "build:",
    "Merge ",
    "Revert ",
)

USER_FACING_PREFIXES = ("add ", "fix ", "implement ", "introduce ", "complete ", "restore ", "pause ", "guard ")
USER_FACING_TYPES = ("feat", "content", "perf")
TECHNICAL_TYPES = ("refactor", "style", "chore", "ci", "docs", "build", "test")

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


def run(*args: str) -> str:
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, check=True)
    return result.stdout


def latest_tag() -> str | None:
    tags = run("git", "tag", "-l", "v[0-9]*", "--sort=-v:refname").splitlines()
    return tags[0] if tags else None


def commit_messages(since_tag: str | None) -> list[tuple[str, str]]:
    log_range = f"{since_tag}..HEAD" if since_tag else "HEAD"
    raw = run(
        "git",
        "log",
        log_range,
        "--pretty=format:---%n%B",
        "--no-merges",
    )
    commits: list[tuple[str, str]] = []
    for block in raw.split("---\n"):
        block = block.strip()
        if not block:
            continue
        lines = block.splitlines()
        subject = lines[0].strip()
        body = "\n".join(lines[1:]).strip()
        commits.append((subject, body))
    return commits


def is_user_facing(subject: str, body: str) -> bool:
    if any(subject.startswith(prefix) for prefix in SKIP_PREFIXES):
        return False
    if re.search(r"^User-Facing:\s*no\s*$", body, re.MULTILINE | re.IGNORECASE):
        return False
    if re.search(r"^User-Facing:\s*yes\s*$", body, re.MULTILINE | re.IGNORECASE):
        return True
    lowered = subject.lower()
    if lowered.startswith(("fix(ci)", "fix(content)", "style", "chore(release)")):
        return False
    if lowered.startswith(USER_FACING_PREFIXES):
        return True
    if lowered.startswith(USER_FACING_TYPES):
        return True
    if "test" in lowered and lowered.startswith(("add ", "fix ")):
        return False
    return not lowered.startswith(TECHNICAL_TYPES)


def simplify_line(line: str) -> str:
    line = re.sub(r"`([^`]+)`", r"\1", line)
    line = re.sub(r"\s+", " ", line).strip(" -•\t")
    for term in TECHNICAL_TERMS:
        if term in line:
            return ""
    return line


def subject_to_user_line(subject: str) -> str:
    line = subject
    line = re.sub(r"^(feat|fix|content|perf)(\([^)]+\))?:\s*", "", line, flags=re.IGNORECASE)
    line = simplify_line(line)
    if not line:
        return ""
    if not line[0].isupper():
        line = line[0].upper() + line[1:]
    return line


def extract_bullets(body: str) -> list[str]:
    bullets: list[str] = []
    for raw in body.splitlines():
        raw = raw.strip()
        if raw.startswith("- "):
            cleaned = simplify_line(raw[2:])
            if cleaned and not cleaned.lower().startswith(("co-authored-by", "user-facing:")):
                bullets.append(cleaned)
    return bullets


def build_notes(commits: list[tuple[str, str]], version: str) -> tuple[str, list[str]]:
    headlines: list[str] = []
    detail_bullets: list[str] = []

    for subject, body in commits:
        if not is_user_facing(subject, body):
            continue
        headline = subject_to_user_line(subject)
        if headline:
            headlines.append(headline)
        for bullet in extract_bullets(body):
            if bullet not in detail_bullets:
                detail_bullets.append(bullet)

    if not headlines and not detail_bullets:
        summary = "Bug fixes and improvements."
        bullets = ["• Stability and performance improvements"]
        return summary, bullets

    summary = headlines[0] if headlines else detail_bullets[0]
    if len(summary) > 150:
        summary = summary[:147].rstrip() + "..."

    bullets: list[str] = []
    for item in headlines[:3]:
        bullets.append(f"• {item}")
    for item in detail_bullets:
        formatted = f"• {item}"
        if formatted not in bullets and len(bullets) < 6:
            bullets.append(formatted)

    if not bullets:
        bullets = [f"• {summary}"]

    return summary, bullets


def validate_notes(summary: str, bullets: list[str]) -> None:
    full = summary + "\n\n" + "\n".join(bullets)
    if len(full) > 4000:
        raise SystemExit(f"Release notes exceed 4000 characters ({len(full)}). Trim before shipping.")
    if len(summary) > 150:
        print(f"Warning: summary line is {len(summary)} chars (App Store truncates around 150).", file=sys.stderr)


def write_prompt(version: str, summary: str, bullets: list[str], commits: list[tuple[str, str]]) -> None:
    dev_lines = []
    for subject, body in commits:
        if is_user_facing(subject, body):
            dev_lines.append(f"- {subject}")
            for b in extract_bullets(body)[:2]:
                dev_lines.append(f"  - {b}")

    prompt = f"""# Release Notes Prompt (v{version})

Use this when asking an agent to polish App Store copy. The deterministic draft is
already written to `ReleaseNotes/en-US.txt`.

## Instructions

Rewrite the developer changelog below into App Store "What's New" copy for Trinket,
a portrait fantasy idle auto-battler. Requirements:

- Plain text only (no markdown)
- First line: compelling summary, max 150 characters
- 3–6 bullet lines starting with •
- Player benefit language; no CI, test, refactor, or tooling jargon
- Total length under 4000 characters

## Current Draft

{summary}

{chr(10).join(bullets)}

## Developer Source

{chr(10).join(dev_lines) if dev_lines else "- (no user-facing commits)"}
"""
    PROMPT.write_text(prompt, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate App Store release notes.")
    parser.add_argument("--version", help="Release version (e.g. 0.2.0)")
    parser.add_argument("--since-tag", help="Git tag to start from (default: latest v* tag)")
    parser.add_argument("--dry-run", action="store_true", help="Print to stdout only")
    args = parser.parse_args()

    since = args.since_tag or latest_tag()
    commits = commit_messages(since)
    version = args.version or "unreleased"

    summary, bullets = build_notes(commits, version)
    validate_notes(summary, bullets)

    content = summary + "\n\n" + "\n".join(bullets) + "\n"

    if args.dry_run:
        print(content)
        return

    write_prompt(version, summary, bullets, commits)
    OUTPUT.write_text(content, encoding="utf-8")
    FASTLANE.parent.mkdir(parents=True, exist_ok=True)
    FASTLANE.write_text(content, encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")
    print(f"Wrote {FASTLANE.relative_to(ROOT)}")
    print(f"Wrote {PROMPT.relative_to(ROOT)} (optional AI polish prompt)")


if __name__ == "__main__":
    main()
