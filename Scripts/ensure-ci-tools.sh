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

install_xcodegen() {
  # XcodeGen writes the committed project, so use a checksummed release rather
  # than whichever Homebrew formula happens to be current on the runner.
  [[ "$os" == "darwin" ]] || return 0

  local bin="$TOOLS_DIR/xcodegen"
  if [[ -x "$bin" ]] && [[ "$("$bin" --version 2>/dev/null | awk '{print $NF}' || true)" == "$XCODEGEN_VERSION" ]]; then
    return 0
  fi

  local tmpdir archive actual_sha install_dir
  tmpdir="$(mktemp -d)"
  archive="$tmpdir/xcodegen.zip"
  install_dir="$TOOLS_DIR/xcodegen-$XCODEGEN_VERSION"

  curl -fsSL "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip" -o "$archive"
  actual_sha="$(shasum -a 256 "$archive" | awk '{print $1}')"
  if [[ "$actual_sha" != "$XCODEGEN_SHA256" ]]; then
    echo "XcodeGen checksum mismatch: expected $XCODEGEN_SHA256, found $actual_sha" >&2
    rm -rf "$tmpdir"
    exit 1
  fi

  rm -rf "$install_dir"
  unzip -qo "$archive" -d "$tmpdir"
  mv "$tmpdir/xcodegen" "$install_dir"
  ln -sfn "xcodegen-$XCODEGEN_VERSION/bin/xcodegen" "$bin"
  rm -rf "$tmpdir"

  local actual
  actual="$("$bin" --version | awk '{print $NF}')"
  if [[ "$actual" != "$XCODEGEN_VERSION" ]]; then
    echo "XcodeGen version mismatch after install: expected $XCODEGEN_VERSION, found $actual" >&2
    exit 1
  fi
}

install_ripgrep() {
  local bin="$TOOLS_DIR/rg"
  if [[ -x "$bin" ]] && [[ "$("$bin" --version 2>/dev/null | head -n 1 | awk '{print $2}' || true)" == "$RIPGREP_VERSION" ]]; then
    return 0
  fi

  local target checksum tmpdir archive actual_sha candidate
  case "$os-$arch" in
    darwin-arm64 | darwin-aarch64)
      target="aarch64-apple-darwin"
      checksum="$RIPGREP_DARWIN_ARM64_SHA256"
      ;;
    darwin-x86_64 | darwin-amd64)
      target="x86_64-apple-darwin"
      checksum="$RIPGREP_DARWIN_X86_64_SHA256"
      ;;
    linux-arm64 | linux-aarch64)
      target="aarch64-unknown-linux-gnu"
      checksum="$RIPGREP_LINUX_ARM64_SHA256"
      ;;
    linux-x86_64 | linux-amd64)
      target="x86_64-unknown-linux-musl"
      checksum="$RIPGREP_LINUX_X86_64_SHA256"
      ;;
    *)
      echo "Unsupported OS/architecture for ripgrep: $os/$arch" >&2
      exit 1
      ;;
  esac

  tmpdir="$(mktemp -d)"
  archive="$tmpdir/ripgrep.tar.gz"
  curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${target}.tar.gz" -o "$archive"
  actual_sha="$(shasum -a 256 "$archive" | awk '{print $1}')"
  if [[ "$actual_sha" != "$checksum" ]]; then
    echo "ripgrep checksum mismatch: expected $checksum, found $actual_sha" >&2
    rm -rf "$tmpdir"
    exit 1
  fi

  tar -xzf "$archive" -C "$tmpdir"
  candidate="$(find "$tmpdir" -type f -name rg -print -quit)"
  if [[ -z "$candidate" ]]; then
    echo "ripgrep binary not found in release archive." >&2
    rm -rf "$tmpdir"
    exit 1
  fi
  install -m 755 "$candidate" "$bin"
  rm -rf "$tmpdir"
}

install_swiftformat
install_swiftlint
install_xcodegen
install_ripgrep

export PATH="$TOOLS_DIR:$PATH"
echo "CI tools ready: SwiftFormat $($TOOLS_DIR/swiftformat --version), SwiftLint $($TOOLS_DIR/swiftlint version), XcodeGen $($TOOLS_DIR/xcodegen --version 2>/dev/null | awk '{print $NF}' || echo unavailable), ripgrep $($TOOLS_DIR/rg --version | head -n 1)"
