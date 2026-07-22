#!/usr/bin/env bash
# Installs git-cliff to .tools/git-cliff if not already present.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/.tools/git-cliff"
source "$ROOT/Scripts/tool-versions.env"
VERSION="$GIT_CLIFF_VERSION"
MARKER="$ROOT/.tools/.git-cliff.sha256"

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

if [[ -x "$BIN" && -f "$MARKER" ]] \
  && [[ "$(awk -F= '$1 == "archive" { print $2; exit }' "$MARKER")" == "$checksum" ]] \
  && [[ "$(awk -F= '$1 == "binary" { print $2; exit }' "$MARKER")" == "$(shasum -a 256 "$BIN" | awk '{print $1}')" ]] \
  && [[ "$("$BIN" --version 2>/dev/null || true)" == *"$VERSION"* ]]; then
  exec "$BIN" "$@"
fi

mkdir -p "$ROOT/.tools"

url="https://github.com/orhun/git-cliff/releases/download/v${VERSION}/${archive}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "Installing git-cliff ${VERSION} from ${url}..."
archive_path="$tmpdir/archive.tar.gz"
curl -fsSL "$url" -o "$archive_path"
actual="$(shasum -a 256 "$archive_path" | awk '{print $1}')"
if [[ "$actual" != "$checksum" ]]; then
  echo "git-cliff checksum mismatch: expected $checksum, found $actual" >&2
  exit 1
fi
tar xzf "$archive_path" -C "$tmpdir"
candidate="$tmpdir/git-cliff-${VERSION}/git-cliff"
if [[ ! -f "$candidate" ]]; then
  echo "git-cliff binary not found in release archive." >&2
  exit 1
fi
install -m 755 "$candidate" "$BIN.tmp"
mv -f "$BIN.tmp" "$BIN"
printf 'archive=%s\nbinary=%s\n' "$checksum" "$(shasum -a 256 "$BIN" | awk '{print $1}')" > "$MARKER"

exec "$BIN" "$@"
