#!/usr/bin/env bash
# Installs pinned git-cliff to .tools/git-cliff if not already present, then execs it.
# Tarball download/verify/marker mechanics are shared with ensure-ci-tools.sh
# via Scripts/lib/tool-install.sh; only the git-cliff platform mapping lives here.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/.tools/git-cliff"
# shellcheck source=tool-versions.env
source "$ROOT/Scripts/tool-versions.env"
TOOLS_DIR="$ROOT/.tools"
# shellcheck source=lib/tool-install.sh
source "$ROOT/Scripts/lib/tool-install.sh"
VERSION="$GIT_CLIFF_VERSION"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$os-$arch" in
  linux-x86_64|linux-amd64)
    archive="git-cliff-${VERSION}-x86_64-unknown-linux-gnu.tar.gz"
    checksum="$GIT_CLIFF_LINUX_X86_64_SHA256"
    ;;
  linux-aarch64|linux-arm64)
    archive="git-cliff-${VERSION}-aarch64-unknown-linux-gnu.tar.gz"
    checksum="$GIT_CLIFF_LINUX_ARM64_SHA256"
    ;;
  darwin-x86_64|darwin-amd64)
    archive="git-cliff-${VERSION}-x86_64-apple-darwin.tar.gz"
    checksum="$GIT_CLIFF_DARWIN_X86_64_SHA256"
    ;;
  darwin-aarch64|darwin-arm64)
    archive="git-cliff-${VERSION}-aarch64-apple-darwin.tar.gz"
    checksum="$GIT_CLIFF_DARWIN_ARM64_SHA256"
    ;;
  *)
    echo "Unsupported OS/architecture: $os/$arch" >&2
    exit 1
    ;;
esac

if trinket_tool_marker_fresh git-cliff "$BIN" "$checksum" \
  && [[ "$("$BIN" --version 2>/dev/null || true)" == *"$VERSION"* ]]; then
  exec "$BIN" "$@"
fi

mkdir -p "$TOOLS_DIR"

url="https://github.com/orhun/git-cliff/releases/download/v${VERSION}/${archive}"
echo "Installing git-cliff ${VERSION} from ${url}..."
tmpdir="$(trinket_tool_fetch_tarball "$url" "$checksum" "git-cliff")"
trap 'rm -rf "$tmpdir"' EXIT

tar xzf "$tmpdir/archive.tar.gz" -C "$tmpdir"
candidate="$tmpdir/git-cliff-${VERSION}/git-cliff"
if [[ ! -f "$candidate" ]]; then
  echo "git-cliff binary not found in release archive." >&2
  exit 1
fi
install -m 755 "$candidate" "$BIN.tmp"
mv -f "$BIN.tmp" "$BIN"
trinket_tool_write_marker git-cliff "$BIN" "$checksum"

exec "$BIN" "$@"
