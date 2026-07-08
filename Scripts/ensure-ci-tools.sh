#!/usr/bin/env bash
# Install pinned SwiftFormat / SwiftLint into .tools/ (gitignored).
# Prefer these over Homebrew so CI and local gates share exact versions.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tool-versions.env
source "$ROOT/Scripts/tool-versions.env"

TOOLS_DIR="$ROOT/.tools"
mkdir -p "$TOOLS_DIR"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"

download_unzip() {
  local url="$1"
  local dest="$2"
  local archive tmpdir
  tmpdir="$(mktemp -d)"
  archive="$tmpdir/tool.zip"
  curl -fsSL "$url" -o "$archive"
  unzip -qo "$archive" -d "$tmpdir"
  # Copy extracted tree into dest for caller inspection.
  mkdir -p "$dest"
  cp -R "$tmpdir"/. "$dest"/
  rm -rf "$tmpdir"
}

install_swiftformat() {
  local bin="$TOOLS_DIR/swiftformat"
  if [[ -x "$bin" ]] && [[ "$("$bin" --version 2>/dev/null || true)" == "$SWIFTFORMAT_VERSION" ]]; then
    return 0
  fi

  local url extract archive
  extract="$(mktemp -d)"

  case "$os" in
    darwin)
      archive="swiftformat.zip"
      ;;
    linux)
      case "$arch" in
        x86_64 | amd64) archive="swiftformat_linux.zip" ;;
        aarch64 | arm64) archive="swiftformat_linux_aarch64.zip" ;;
        *)
          echo "Unsupported architecture for SwiftFormat: $arch" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Unsupported OS for SwiftFormat install: $os" >&2
      exit 1
      ;;
  esac

  url="https://github.com/nicklockwood/SwiftFormat/releases/download/${SWIFTFORMAT_VERSION}/${archive}"
  echo "Installing SwiftFormat ${SWIFTFORMAT_VERSION} from ${url}..."
  download_unzip "$url" "$extract"

  if [[ -f "$extract/swiftformat_linux" ]]; then
    install -m 755 "$extract/swiftformat_linux" "$bin"
  elif [[ -f "$extract/swiftformat" ]]; then
    install -m 755 "$extract/swiftformat" "$bin"
  else
    echo "SwiftFormat binary not found in release archive." >&2
    rm -rf "$extract"
    exit 1
  fi
  rm -rf "$extract"

  local actual
  actual="$("$bin" --version)"
  if [[ "$actual" != "$SWIFTFORMAT_VERSION" ]]; then
    echo "SwiftFormat version mismatch after install: expected $SWIFTFORMAT_VERSION, found $actual" >&2
    exit 1
  fi
}

install_swiftlint() {
  local bin="$TOOLS_DIR/swiftlint"
  if [[ -x "$bin" ]] && [[ "$("$bin" version 2>/dev/null || true)" == "$SWIFTLINT_VERSION" ]]; then
    return 0
  fi

  local url extract archive candidate
  extract="$(mktemp -d)"

  case "$os" in
    darwin)
      archive="portable_swiftlint.zip"
      ;;
    linux)
      case "$arch" in
        x86_64 | amd64) archive="swiftlint_linux_amd64.zip" ;;
        aarch64 | arm64) archive="swiftlint_linux_arm64.zip" ;;
        *)
          echo "Unsupported architecture for SwiftLint: $arch" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Unsupported OS for SwiftLint install: $os" >&2
      exit 1
      ;;
  esac

  url="https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/${archive}"
  echo "Installing SwiftLint ${SWIFTLINT_VERSION} from ${url}..."
  download_unzip "$url" "$extract"

  candidate=""
  if [[ -f "$extract/swiftlint-static" ]]; then
    candidate="$extract/swiftlint-static"
  elif [[ -f "$extract/swiftlint" ]]; then
    candidate="$extract/swiftlint"
  else
    candidate="$(find "$extract" -type f -name swiftlint -print -quit || true)"
  fi
  if [[ -z "$candidate" || ! -f "$candidate" ]]; then
    echo "SwiftLint binary not found in release archive." >&2
    rm -rf "$extract"
    exit 1
  fi
  install -m 755 "$candidate" "$bin"
  rm -rf "$extract"

  local actual
  actual="$("$bin" version)"
  if [[ "$actual" != "$SWIFTLINT_VERSION" ]]; then
    echo "SwiftLint version mismatch after install: expected $SWIFTLINT_VERSION, found $actual" >&2
    exit 1
  fi
}

install_swiftformat
install_swiftlint

export PATH="$TOOLS_DIR:$PATH"
echo "CI tools ready: SwiftFormat $($TOOLS_DIR/swiftformat --version), SwiftLint $($TOOLS_DIR/swiftlint version)"
