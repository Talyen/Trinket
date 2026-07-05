#!/usr/bin/env bash
# Installs git-cliff to .tools/git-cliff if not already present.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/.tools/git-cliff"
VERSION="2.13.1"

if [[ -x "$BIN" ]]; then
  exec "$BIN" "$@"
fi

mkdir -p "$ROOT/.tools"

arch="$(uname -m)"
case "$arch" in
  x86_64) arch="x86_64" ;;
  aarch64 | arm64) arch="aarch64" ;;
  *)
    echo "Unsupported architecture: $arch" >&2
    exit 1
    ;;
esac

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$os" in
  linux) archive="git-cliff-${VERSION}-${arch}-unknown-linux-gnu.tar.gz" ;;
  darwin)
    if [[ "$arch" == "aarch64" ]]; then
      archive="git-cliff-${VERSION}-aarch64-apple-darwin.tar.gz"
    else
      archive="git-cliff-${VERSION}-x86_64-apple-darwin.tar.gz"
    fi
    ;;
  *)
    echo "Unsupported OS: $os (install git-cliff via brew: brew install git-cliff)" >&2
    exit 1
    ;;
esac

url="https://github.com/orhun/git-cliff/releases/download/v${VERSION}/${archive}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "Installing git-cliff ${VERSION} from ${url}..."
curl -fsSL "$url" | tar xz -C "$tmpdir"
install -m 755 "$tmpdir/git-cliff-${VERSION}/git-cliff" "$BIN"

exec "$BIN" "$@"
