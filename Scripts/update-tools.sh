#!/usr/bin/env bash
# Bump the pinned SwiftFormat / SwiftLint versions in tool-versions.env to the
# latest GitHub releases and install the local .tools binary. Dry-run by default;
# pass --apply to write the new pins and re-install.
#
# Only SwiftFormat and SwiftLint are automated. The remaining pins (XcodeGen,
# xcbeautify, ripgrep, git-cliff) are bumped manually in tool-versions.env with
# hand-fetched checksums — see ensure-ci-tools.sh for their install recipes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/Scripts/tool-versions.env"
# shellcheck source=tool-versions.env
source "$ENV_FILE"

APPLY=false
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=true
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--apply]" >&2
  exit 1
fi

# Numeric semver compare: `semver_gt A B` is true when A > B.
semver_gt() {
  local a=(${1//./ }) b=(${2//./ })
  for i in 0 1 2; do
    local av="${a[$i]:-0}" bv="${b[$i]:-0}"
    ((10#$av > 10#$bv)) && return 0
    ((10#$av < 10#$bv)) && return 1
  done
  return 1
}

latest_release() { # repo
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))'
}

checksum_for() { # url
  local tmp
  tmp="$(mktemp)"
  curl -fsSL "$1" -o "$tmp"
  shasum -a 256 "$tmp" | awk '{print $1}'
  rm -f "$tmp"
}

rewrite_pins() { # key=value...
  python3 - "$ENV_FILE" "$@" <<'PY'
import sys
path = sys.argv[1]
settings = dict(arg.split("=", 1) for arg in sys.argv[2:])
lines = []
for raw in open(path):
    line = raw.rstrip("\n")
    if "=" in line:
        key, _ = line.split("=", 1)
        if key in settings:
            line = f"{key}={settings[key]}"
    lines.append(line)
open(path, "w").write("\n".join(lines) + "\n")
PY
}

update_tool() { # repo tag_var "SHA_VAR:asset SHA_VAR:asset ..."
  local repo="$1" tag_var="$2" assets="$3"
  local current latest sha_url sha
  current="${!tag_var}"
  echo "Checking $tag_var (pinned $current)..."
  latest="$(latest_release "$repo")"
  if ! semver_gt "$latest" "$current"; then
    echo "  already at latest ($latest); no change."
    return 0
  fi
  echo "  newer release available: $latest"
  if ! "$APPLY"; then
    echo "  run with --apply to pin ${tag_var}=${latest} and install."
    return 0
  fi

  local updates=("$tag_var=$latest")
  local spec var asset
  for spec in $assets; do
    var="${spec%%:*}"
    asset="${spec#*:}"
    sha_url="https://github.com/${repo}/releases/download/${latest}/${asset}"
    echo "  checksumming ${asset}..."
    sha="$(checksum_for "$sha_url")"
    updates+=("$var=$sha")
  done
  rewrite_pins "${updates[@]}"
  echo "  updated $ENV_FILE; installing pinned binary..."
  "$ROOT/Scripts/ensure-ci-tools.sh"
}

update_tool nicklockwood/SwiftFormat SWIFTFORMAT_VERSION \
  "SWIFTFORMAT_DARWIN_SHA256:swiftformat.zip \
   SWIFTFORMAT_LINUX_X86_64_SHA256:swiftformat_linux.zip \
   SWIFTFORMAT_LINUX_ARM64_SHA256:swiftformat_linux_aarch64.zip"

update_tool realm/SwiftLint SWIFTLINT_VERSION \
  "SWIFTLINT_DARWIN_SHA256:portable_swiftlint.zip \
   SWIFTLINT_LINUX_X86_64_SHA256:swiftlint_linux_amd64.zip \
   SWIFTLINT_LINUX_ARM64_SHA256:swiftlint_linux_arm64.zip"

echo "SwiftFormat/SwiftLint pins current."
