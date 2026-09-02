#!/usr/bin/env bash
# Per-tool installer for ripgrep (sourced by ensure-ci-tools.sh).
install_ripgrep() {
  local bin="$TOOLS_DIR/rg"
  local target checksum tmpdir candidate
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

  if trinket_tool_marker_fresh rg "$bin" "$checksum" \
    && [[ "$("$bin" --version 2>/dev/null | head -n 1 | awk '{print $2}' || true)" == "$RIPGREP_VERSION" ]]; then
    return 0
  fi

  tmpdir="$(trinket_tool_fetch_tarball "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${target}.tar.gz" "$checksum" "ripgrep")"
  tar -xzf "$tmpdir/archive.tar.gz" -C "$tmpdir"
  candidate="$(find "$tmpdir" -type f -name rg -print -quit)"
  if [[ -z "$candidate" ]]; then
    echo "ripgrep binary not found in release archive." >&2
    rm -rf "$tmpdir"
    exit 1
  fi
  install -m 755 "$candidate" "$bin"
  trinket_tool_write_marker rg "$bin" "$checksum"
  rm -rf "$tmpdir"
}
