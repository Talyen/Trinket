#!/usr/bin/env python3
"""Pin StoreKit configuration files into generated schemes.

The pinned XcodeGen does not emit `storeKitConfiguration` (neither the run
nor the test action), so `project.yml` keys would otherwise be silently
ignored: the app and UI tests launch without the test store and
`Product.products(for:)` resolves nothing. This step reads
`schemes.<name>.run.storeKitConfiguration` from the authored `project.yml`
and ensures each generated `<scheme>.xcscheme` carries the matching
`<StoreKitConfigurationFileReference>` child under `<LaunchAction>`.
(Xcode only honors the Run action slot; the Test action has no such setting.)

Runs inside `trinket_generate_project`, so normal generation, the staged
project gate, and the push gate all converge on the same schemes. The edit is
a no-op when nothing changed, keeping regeneration idempotent.
"""

import argparse
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape


def strip_comment(value):
    in_single = False
    in_double = False
    for index, char in enumerate(value):
        if char == "'" and not in_double:
            in_single = not in_single
        elif char == '"' and not in_single:
            in_double = not in_double
        elif char == "#" and not in_single and not in_double:
            if index == 0 or value[index - 1] in (" ", "\t"):
                return value[:index]
    return value


def unquote(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        return value[1:-1]
    return value


def scheme_run_storekit_paths(spec_text):
    """Map scheme name to its run.storeKitConfiguration path from project.yml."""
    found = {}
    scheme = None
    in_schemes = False
    in_run = False
    for raw_line in spec_text.splitlines():
        line = strip_comment(raw_line).rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()
        if indent == 0:
            in_schemes = stripped == "schemes:"
            scheme = None
            in_run = False
            continue
        if not in_schemes:
            continue
        if indent == 2 and stripped.endswith(":"):
            scheme = stripped[:-1]
            in_run = False
            continue
        if scheme is None:
            continue
        if indent == 4 and stripped.endswith(":"):
            in_run = stripped[:-1] == "run"
            continue
        if indent <= 4:
            in_run = False
            continue
        if in_run and indent == 6 and stripped.startswith("storeKitConfiguration:"):
            found[scheme] = unquote(stripped.split(":", 1)[1])
    return found


ELEMENT_RE = re.compile(
    r"<StoreKitConfigurationFileReference\b[^>]*/>"
    r"|<StoreKitConfigurationFileReference\b[^>]*>.*?"
    r"</StoreKitConfigurationFileReference>",
    re.DOTALL,
)
LAUNCH_OPEN_RE = re.compile(r"<LaunchAction\b[^>]*>")


def canonical_element(identifier):
    quoted = escape(identifier).replace('"', "&quot;")
    return (
        "      <StoreKitConfigurationFileReference\n"
        f'         identifier = "{quoted}">\n'
        "      </StoreKitConfigurationFileReference>"
    )


def patch_scheme(text, identifier):
    match = LAUNCH_OPEN_RE.search(text)
    if match is None:
        raise ValueError("scheme has no <LaunchAction> element")
    close_tag = "</LaunchAction>"
    block_start = match.start()
    block_end = text.find(close_tag, match.end())
    if block_end == -1:
        raise ValueError("scheme has unterminated <LaunchAction> element")
    block = text[block_start:block_end]
    cleaned = ELEMENT_RE.sub("", block)
    cleaned = re.sub(r"\n[ \t]*\n", "\n", cleaned)
    close_match = re.search(r"\n([ \t]*)$", cleaned)
    if close_match is not None:
        indent = close_match.group(1)
        head = cleaned[:close_match.start()]
    else:
        indent = "    "
        head = cleaned.rstrip()
    rebuilt = head + "\n" + canonical_element(identifier) + "\n" + indent
    updated = text[:block_start] + rebuilt + text[block_end:]
    return updated, updated != text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", required=True)
    args = parser.parse_args()
    root = Path(args.project_root)
    spec_path = root / "project.yml"
    if not spec_path.is_file():
        return 0
    wanted = scheme_run_storekit_paths(spec_path.read_text())
    if not wanted:
        return 0
    schemes_dir = root / "Trinket.xcodeproj/xcshareddata/xcschemes"
    if not schemes_dir.is_dir():
        return 0
    changed = []
    for scheme, identifier in sorted(wanted.items()):
        if not (root / identifier).is_file():
            print(f"error: {spec_path}: scheme {scheme} run.storeKitConfiguration "
                  f"points at missing file {identifier}", file=sys.stderr)
            return 1
        scheme_path = schemes_dir / f"{scheme}.xcscheme"
        if not scheme_path.is_file():
            print(f"warning: generated scheme {scheme_path} not found; skipping")
            continue
        text = scheme_path.read_text()
        try:
            updated, did_change = patch_scheme(text, identifier)
        except ValueError as error:
            print(f"error: {scheme_path}: {error}", file=sys.stderr)
            return 1
        if did_change:
            scheme_path.write_text(updated)
            changed.append(scheme)
    for scheme in changed:
        print(f"pinned StoreKit configuration for scheme {scheme}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
