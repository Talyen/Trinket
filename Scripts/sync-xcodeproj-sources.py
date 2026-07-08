#!/usr/bin/env python3
"""Sync folder-scanned Swift sources in Trinket.xcodeproj/project.pbxproj.

XcodeGen normally regenerates this file. On Linux we patch the committed project
so CI assert-generated-output stays green when test files are added or removed.
"""

from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = ROOT / "Trinket.xcodeproj" / "project.pbxproj"

# PBXSourcesBuildPhase IDs from the committed project.
TARGET_SOURCE_PHASES = {
    "TrinketTests": "4479C389B51D310F83EADE2C",
    "TrinketUITests": "9BAF02F2F9AB43DD87FC4C7C",
    "Trinket": "E8F0A1B2C3D4E5F60718293A",  # filled below if missing
}

TARGET_ROOTS = {
    "TrinketTests": ROOT / "TrinketTests",
    "TrinketUITests": ROOT / "TrinketUITests",
    "Trinket": ROOT / "Trinket",
}

TARGET_EXTRA_SOURCES = {
    "TrinketUITests": [ROOT / "Trinket" / "Shared" / "AccessibilityID.swift"],
}


def make_id(seed: str) -> str:
    digest = hashlib.md5(seed.encode()).hexdigest().upper()
    return digest[:24]


def discover_swift_files(folder: Path) -> list[Path]:
    return sorted(folder.rglob("*.swift"))


def rel_path(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def basename(path: Path) -> str:
    return path.name


def read_pbx() -> str:
    return PBX.read_text()


def write_pbx(text: str) -> None:
    PBX.write_text(text)


def find_trinket_sources_phase(text: str) -> str | None:
    match = re.search(
        r"([0-9A-F]{24}) /\* Sources \*/ = \{\n\t\t\tisa = PBXSourcesBuildPhase;",
        text,
    )
    # Trinket app Sources phase is the first one before TrinketTests.
    phases = re.findall(
        r"([0-9A-F]{24}) /\* Sources \*/ = \{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = \((.*?)\);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t\};",
        text,
        flags=re.DOTALL,
    )
    if len(phases) >= 1:
        return phases[0][0]
    return None


def parse_file_refs(text: str) -> dict[str, str]:
    """Map basename -> PBXFileReference ID."""
    refs: dict[str, str] = {}
    for match in re.finditer(
        r"([0-9A-F]{24}) /\* (.+?) \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = (.+?); sourceTree = \"<group>\"; \};",
        text,
    ):
        refs[match.group(3)] = match.group(1)
    return refs


def parse_build_files(text: str) -> dict[str, str]:
    """Map PBXFileReference ID -> PBXBuildFile ID."""
    mapping: dict[str, str] = {}
    for match in re.finditer(
        r"([0-9A-F]{24}) /\* (.+?) in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([0-9A-F]{24})",
        text,
    ):
        mapping[match.group(3)] = match.group(1)
    return mapping


def extract_phase_entries(text: str, phase_id: str) -> list[tuple[str, str]]:
    """Return [(build_file_id, basename), ...] for a sources phase."""
    pattern = (
        rf"{phase_id} /\* Sources \*/ = \{{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = \((.*?)\);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t\}};"
    )
    match = re.search(pattern, text, flags=re.DOTALL)
    if not match:
        raise SystemExit(f"Could not find sources phase {phase_id}")
    block = match.group(1)
    return re.findall(r"([0-9A-F]{24}) /\* (.+?) in Sources \*/", block)


def extract_phase_files(text: str, phase_id: str) -> list[str]:
    return [build_id for build_id, _ in extract_phase_entries(text, phase_id)]


def replace_phase_files(text: str, phase_id: str, build_file_ids: list[str], names: dict[str, str]) -> str:
    entries = "\n".join(
        f"\t\t\t\t{id_} /* {names[id_]} in Sources */," for id_ in build_file_ids
    )
    pattern = (
        rf"({phase_id} /\* Sources \*/ = \{{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = \()(.*?)(\);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t\}};)"
    )
    replacement = rf"\1\n{entries}\n\t\t\t\3"
    return re.sub(pattern, replacement, text, count=1, flags=re.DOTALL)


def ensure_file_reference(text: str, path: Path, refs: dict[str, str]) -> tuple[str, str]:
    name = basename(path)
    if name in refs:
        return text, refs[name]
    file_id = make_id(f"fileref:{rel_path(path)}")
    entry = (
        f"\t\t{file_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n"
    )
    text = text.replace("/* End PBXFileReference section */\n", entry + "/* End PBXFileReference section */\n")
    refs[name] = file_id
    return text, file_id


def ensure_build_file(text: str, path: Path, file_id: str, build_files: dict[str, str]) -> tuple[str, str]:
    if file_id in build_files:
        return text, build_files[file_id]
    name = basename(path)
    build_id = make_id(f"buildfile:{rel_path(path)}")
    build_entry = (
        f"\t\t{build_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {name} */; }};\n"
    )
    text = text.replace("/* End PBXBuildFile section */\n", build_entry + "/* End PBXBuildFile section */\n")
    build_files[file_id] = build_id
    return text, build_id


def sync_target(text: str, target: str, phase_id: str) -> str:
    """Add missing Swift sources and drop deleted ones without reshuffling IDs.

    Preserves existing PBXBuildFile / PBXFileReference IDs and phase order so Linux
    sync does not fight XcodeGen's committed UUIDs when the file set is unchanged.
    Matches by the phase comment basename (not fileRef maps) so shared sources like
    AccessibilityID.swift can appear in multiple targets.
    """
    root = TARGET_ROOTS[target]
    desired = {basename(p): p for p in discover_swift_files(root)}
    for extra in TARGET_EXTRA_SOURCES.get(target, []):
        if extra.exists():
            desired[basename(extra)] = extra
    refs = parse_file_refs(text)
    build_files = parse_build_files(text)

    kept: list[str] = []
    names: dict[str, str] = {}
    present_names: set[str] = set()

    for build_id, name in extract_phase_entries(text, phase_id):
        if name not in desired:
            continue
        kept.append(build_id)
        names[build_id] = name
        present_names.add(name)

    for name in sorted(desired):
        if name in present_names:
            continue
        path = desired[name]
        text, file_id = ensure_file_reference(text, path, refs)
        # Prefer a dedicated build-file ID keyed by target+path so shared sources
        # (e.g. AccessibilityID in UITests) do not collide across targets.
        dedicated_key = f"buildfile:{target}:{rel_path(path)}"
        dedicated_id = make_id(dedicated_key)
        if dedicated_id not in {bid for bid, _ in extract_phase_entries(text, phase_id)} and dedicated_id not in names:
            if f"{dedicated_id} /* {name} in Sources */" not in text:
                build_entry = (
                    f"\t\t{dedicated_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {name} */; }};\n"
                )
                text = text.replace(
                    "/* End PBXBuildFile section */\n",
                    build_entry + "/* End PBXBuildFile section */\n",
                )
            build_id = dedicated_id
        else:
            text, build_id = ensure_build_file(text, path, file_id, build_files)
        kept.append(build_id)
        names[build_id] = name

    return replace_phase_files(text, phase_id, kept, names)


def remove_missing_app_sources(text: str, phase_id: str) -> str:
    root = TARGET_ROOTS["Trinket"]
    desired = {basename(p) for p in discover_swift_files(root)}
    refs = parse_file_refs(text)
    build_files = parse_build_files(text)

    current_build_ids = extract_phase_files(text, phase_id)
    kept: list[str] = []
    names: dict[str, str] = {}

    for build_id in current_build_ids:
        file_ref = next((fid for fid, bid in build_files.items() if bid == build_id), None)
        if file_ref is None:
            continue
        name = next((n for n, fid in refs.items() if fid == file_ref), None)
        if name is None:
            continue
        if name in desired:
            kept.append(build_id)
            names[build_id] = name

    return replace_phase_files(text, phase_id, kept, names)


def find_app_sources_phase_id(text: str) -> str:
    """Return the Trinket app PBXSourcesBuildPhase ID (the phase that includes BattleCombatantPane)."""
    phases = re.findall(
        r"([0-9A-F]{24}) /\* Sources \*/ = \{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = \((.*?)\);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t\};",
        text,
        flags=re.DOTALL,
    )
    for phase_id, block in phases:
        if "BattleCombatantPane.swift in Sources" in block:
            return phase_id
    raise SystemExit("Could not locate Trinket app Sources build phase")


def ensure_group_membership(text: str, path: Path, file_id: str) -> str:
    """Add a file reference to its parent PBXGroup when missing."""
    group_name = path.parent.name
    escaped = re.escape(group_name)
    pattern = (
        r"([0-9A-F]{24}) /\* "
        + escaped
        + r" \*/ = \{\n"
        + r"\t\t\tisa = PBXGroup;\n"
        + r"\t\t\tchildren = \((.*?)\);\n"
        + r"\t\t\tpath = "
        + escaped
        + r";\n"
        + r"\t\t\tsourceTree = \"<group>\";\n"
        + r"\t\t\};"
    )
    match = re.search(pattern, text, flags=re.DOTALL)
    if not match:
        return text
    children = match.group(2)
    if file_id in children:
        return text
    name = basename(path)
    insertion = f"\n\t\t\t\t{file_id} /* {name} */,"
    new_children = children.rstrip() + insertion + "\n\t\t\t"
    start, end = match.start(2), match.end(2)
    return text[:start] + new_children + text[end:]


def sync_app_target(text: str) -> str:
    phase_id = find_app_sources_phase_id(text)
    before_refs = parse_file_refs(text)
    text = sync_target(text, "Trinket", phase_id)
    after_refs = parse_file_refs(text)
    for name, file_id in after_refs.items():
        if name in before_refs:
            continue
        # Newly added app source — attach to its folder group when possible.
        path = next(
            (p for p in discover_swift_files(TARGET_ROOTS["Trinket"]) if basename(p) == name),
            None,
        )
        if path is not None:
            text = ensure_group_membership(text, path, file_id)
    return text


def main() -> int:
    text = read_pbx()
    text = sync_target(text, "TrinketTests", TARGET_SOURCE_PHASES["TrinketTests"])
    text = sync_target(text, "TrinketUITests", TARGET_SOURCE_PHASES["TrinketUITests"])
    text = sync_app_target(text)

    stale_trinket_sources = [
        "5A443C6F3C6657CAA87B24FA /* SessionStateStore.swift in Sources */,",
    ]
    for line in stale_trinket_sources:
        text = text.replace(f"\t\t\t\t{line}\n", "")

    write_pbx(text)
    print(f"Synced {PBX}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
