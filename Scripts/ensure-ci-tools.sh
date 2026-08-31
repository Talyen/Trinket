#!/usr/bin/env bash
# Install pinned CI tools into .tools/ (gitignored).
# Prefer these over Homebrew so CI and local gates share exact versions.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tool-versions.env
source "$ROOT/Scripts/tool-versions.env"

TOOLS_DIR="$ROOT/.tools"

usage() {
  cat <<'USAGE'
Usage: ./Scripts/ensure-ci-tools.sh [--check]

Install the pinned CI tools into .tools. Pass --check to validate the existing
tools, versions, and checksum metadata without downloading or changing files.
USAGE
}

mode="install"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      mode="check"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

verify_archive() {
  local archive="$1" expected="$2" label="$3" actual
  actual="$(sha256_file "$archive")"
  if [[ "$actual" != "$expected" ]]; then
    echo "$label checksum mismatch: expected $expected, found $actual" >&2
    return 1
  fi
}

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"

download_unzip() {
  local url="$1"
  local dest="$2"
  local expected="$3"
  local archive tmpdir
  tmpdir="$(mktemp -d)"
  archive="$tmpdir/tool.zip"
  curl -fsSL "$url" -o "$archive"
  verify_archive "$archive" "$expected" "Downloaded archive" || { rm -rf "$tmpdir"; return 1; }
  unzip -qo "$archive" -d "$tmpdir"
  # Copy extracted tree into dest for caller inspection.
  mkdir -p "$dest"
  cp -R "$tmpdir"/. "$dest"/
  rm -rf "$tmpdir"
}

# Release-archive name and checksum per platform. Sets ARCHIVE_NAME and
# ARCHIVE_CHECKSUM; exits on unsupported platforms.
zip_tool_archive() {
  local tool="$1"
  case "$tool:$os-$arch" in
    swiftformat:darwin-*)
      ARCHIVE_NAME="swiftformat.zip"; ARCHIVE_CHECKSUM="$SWIFTFORMAT_DARWIN_SHA256" ;;
    swiftformat:linux-x86_64 | swiftformat:linux-amd64)
      ARCHIVE_NAME="swiftformat_linux.zip"; ARCHIVE_CHECKSUM="$SWIFTFORMAT_LINUX_X86_64_SHA256" ;;
    swiftformat:linux-aarch64 | swiftformat:linux-arm64)
      ARCHIVE_NAME="swiftformat_linux_aarch64.zip"; ARCHIVE_CHECKSUM="$SWIFTFORMAT_LINUX_ARM64_SHA256" ;;
    swiftlint:darwin-*)
      ARCHIVE_NAME="portable_swiftlint.zip"; ARCHIVE_CHECKSUM="$SWIFTLINT_DARWIN_SHA256" ;;
    swiftlint:linux-x86_64 | swiftlint:linux-amd64)
      ARCHIVE_NAME="swiftlint_linux_amd64.zip"; ARCHIVE_CHECKSUM="$SWIFTLINT_LINUX_X86_64_SHA256" ;;
    swiftlint:linux-aarch64 | swiftlint:linux-arm64)
      ARCHIVE_NAME="swiftlint_linux_arm64.zip"; ARCHIVE_CHECKSUM="$SWIFTLINT_LINUX_ARM64_SHA256" ;;
    xcbeautify:darwin-arm64 | xcbeautify:darwin-aarch64)
      ARCHIVE_NAME="xcbeautify-${XCBEAUTIFY_VERSION}-arm64-apple-macosx.zip"; ARCHIVE_CHECKSUM="$XCBEAUTIFY_DARWIN_ARM64_SHA256" ;;
    xcbeautify:darwin-x86_64 | xcbeautify:darwin-amd64)
      ARCHIVE_NAME="xcbeautify-${XCBEAUTIFY_VERSION}-x86_64-apple-macosx.zip"; ARCHIVE_CHECKSUM="$XCBEAUTIFY_DARWIN_X86_64_SHA256" ;;
    *)
      echo "Unsupported OS/architecture for $tool: $os/$arch" >&2
      exit 1
      ;;
  esac
}

# Shared installer for checksummed zip releases with a marker file.
# install_zip_tool <name> <version> <repo-slug> <version-flag> <candidate-binary...>
install_zip_tool() {
  local name="$1" version="$2" slug="$3" version_flag="$4"
  shift 4
  local -a candidates=("$@")
  local bin="$TOOLS_DIR/$name"
  local marker="$TOOLS_DIR/.$name.sha256"

  zip_tool_archive "$name"
  local archive_checksum="$ARCHIVE_CHECKSUM"

  if [[ -x "$bin" && -f "$marker" ]] \
    && [[ "$(awk -F= '$1 == "archive" { print $2; exit }' "$marker")" == "$archive_checksum" ]] \
    && [[ "$(awk -F= '$1 == "binary" { print $2; exit }' "$marker")" == "$(sha256_file "$bin")" ]] \
    && [[ "$("$bin" $version_flag 2>/dev/null || true)" == "$version" ]]; then
    return 0
  fi

  local url extract archive candidate c
  extract="$(mktemp -d)"
  archive="$ARCHIVE_NAME"

  url="https://github.com/${slug}/releases/download/${version}/${archive}"
  echo "Installing ${name} ${version} from ${url}..."
  download_unzip "$url" "$extract" "$archive_checksum"

  candidate=""
  for c in "${candidates[@]}"; do
    if [[ -f "$extract/$c" ]]; then
      candidate="$extract/$c"
      break
    fi
  done
  if [[ -z "$candidate" ]]; then
    candidate="$(find "$extract" -type f -name "$name" -print -quit || true)"
  fi
  if [[ -z "$candidate" || ! -f "$candidate" ]]; then
    echo "${name} binary not found in release archive." >&2
    rm -rf "$extract"
    exit 1
  fi
  install -m 755 "$candidate" "$bin.tmp"
  mv -f "$bin.tmp" "$bin"
  printf 'archive=%s\nbinary=%s\n' "$archive_checksum" "$(sha256_file "$bin")" > "$marker"
  rm -rf "$extract"

  local actual
  actual="$("$bin" $version_flag)"
  if [[ "$actual" != "$version" ]]; then
    echo "${name} version mismatch after install: expected $version, found $actual" >&2
    exit 1
  fi
}

install_swiftformat() {
  install_zip_tool swiftformat "$SWIFTFORMAT_VERSION" nicklockwood/SwiftFormat --version swiftformat_linux swiftformat
}

install_swiftlint() {
  install_zip_tool swiftlint "$SWIFTLINT_VERSION" realm/SwiftLint version swiftlint-static swiftlint
}

install_xcodegen() {
  # XcodeGen writes the committed project, so use a checksummed release rather
  # than whichever Homebrew formula happens to be current on the runner.
  [[ "$os" == "darwin" ]] || return 0

  local bin="$TOOLS_DIR/xcodegen"
  local install_dir="$TOOLS_DIR/xcodegen-$XCODEGEN_VERSION"
  local real_bin="$install_dir/bin/xcodegen"
  local marker="$TOOLS_DIR/.xcodegen.sha256"

  write_xcodegen_wrapper() {
    # XcodeGen resolves SettingPresets from argv[0]/../share/xcodegen. A plain
    # symlink at .tools/xcodegen makes that lookup miss the presets and strip
    # default SDK/runpath settings from project.pbxproj (CI assert drift).
    # Remove any existing symlink first so we do not overwrite the real binary.
    rm -f "$bin"
    cat >"$bin" <<EOF
#!/usr/bin/env bash
exec "$real_bin" "\$@"
EOF
    chmod +x "$bin"
  }

  if [[ -x "$real_bin" && -f "$marker" ]] \
    && [[ "$(awk -F= '$1 == "archive" { print $2; exit }' "$marker")" == "$XCODEGEN_SHA256" ]] \
    && [[ "$(awk -F= '$1 == "binary" { print $2; exit }' "$marker")" == "$(sha256_file "$real_bin")" ]] \
    && [[ "$("$real_bin" --version 2>/dev/null | awk '{print $NF}' || true)" == "$XCODEGEN_VERSION" ]]; then
    write_xcodegen_wrapper
    return 0
  fi

  local tmpdir archive
  tmpdir="$(mktemp -d)"
  archive="$tmpdir/xcodegen.zip"

  curl -fsSL "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip" -o "$archive"
  verify_archive "$archive" "$XCODEGEN_SHA256" "XcodeGen"

  rm -rf "$install_dir"
  unzip -qo "$archive" -d "$tmpdir"
  mv "$tmpdir/xcodegen" "$install_dir"
  write_xcodegen_wrapper
  rm -rf "$tmpdir"

  local actual
  actual="$("$bin" --version | awk '{print $NF}')"
  if [[ "$actual" != "$XCODEGEN_VERSION" ]]; then
    echo "XcodeGen version mismatch after install: expected $XCODEGEN_VERSION, found $actual" >&2
    exit 1
  fi
  printf 'archive=%s\nbinary=%s\n' "$XCODEGEN_SHA256" "$(sha256_file "$real_bin")" > "$marker"
}

install_ripgrep() {
  local bin="$TOOLS_DIR/rg"
  local marker="$TOOLS_DIR/.rg.sha256"
  local target checksum tmpdir archive candidate
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

  if [[ -x "$bin" && -f "$marker" ]] \
    && [[ "$(awk -F= '$1 == "archive" { print $2; exit }' "$marker")" == "$checksum" ]] \
    && [[ "$(awk -F= '$1 == "binary" { print $2; exit }' "$marker")" == "$(sha256_file "$bin")" ]] \
    && [[ "$("$bin" --version 2>/dev/null | head -n 1 | awk '{print $2}' || true)" == "$RIPGREP_VERSION" ]]; then
    return 0
  fi

  tmpdir="$(mktemp -d)"
  archive="$tmpdir/ripgrep.tar.gz"
  curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${target}.tar.gz" -o "$archive"
  verify_archive "$archive" "$checksum" "ripgrep"

  tar -xzf "$archive" -C "$tmpdir"
  candidate="$(find "$tmpdir" -type f -name rg -print -quit)"
  if [[ -z "$candidate" ]]; then
    echo "ripgrep binary not found in release archive." >&2
    rm -rf "$tmpdir"
    exit 1
  fi
  install -m 755 "$candidate" "$bin"
  printf 'archive=%s\nbinary=%s\n' "$checksum" "$(sha256_file "$bin")" > "$marker"
  rm -rf "$tmpdir"
}

install_xcbeautify() {
  # Local/darwin only: CI omits --verbose and uses structured failure reports,
  # so a condensed formatter is only needed on mac for the run/build path.
  [[ "$os" == "darwin" ]] || return 0
  install_zip_tool xcbeautify "$XCBEAUTIFY_VERSION" cpisciotta/xcbeautify --version xcbeautify
}

expected_archive_checksum() {
  local tool="$1"
  case "$tool" in
    swiftformat|swiftlint|xcbeautify)
      zip_tool_archive "$tool"
      printf '%s' "$ARCHIVE_CHECKSUM"
      ;;
    xcodegen)
      printf '%s' "$XCODEGEN_SHA256"
      ;;
    rg)
      case "$os-$arch" in
        darwin-arm64 | darwin-aarch64) printf '%s' "$RIPGREP_DARWIN_ARM64_SHA256" ;;
        darwin-x86_64 | darwin-amd64) printf '%s' "$RIPGREP_DARWIN_X86_64_SHA256" ;;
        linux-arm64 | linux-aarch64) printf '%s' "$RIPGREP_LINUX_ARM64_SHA256" ;;
        linux-x86_64 | linux-amd64) printf '%s' "$RIPGREP_LINUX_X86_64_SHA256" ;;
        *) return 1 ;;
      esac
      ;;
    *)
      return 1
      ;;
  esac
}

check_binary() {
  local name="$1" bin="$2" expected="$3" actual=""
  if [[ ! -e "$bin" ]]; then
    echo "Missing pinned tool: $bin" >&2
    return 1
  fi
  if [[ ! -x "$bin" ]]; then
    echo "Pinned tool is not executable: $bin" >&2
    return 1
  fi

  case "$name" in
    swiftformat|xcodegen|xcbeautify)
      actual="$("$bin" --version 2>/dev/null || true)"
      if [[ "$name" == xcodegen ]]; then
        actual="$(awk '{print $NF}' <<< "$actual")"
      fi
      ;;
    swiftlint)
      actual="$("$bin" version 2>/dev/null || true)"
      ;;
    rg)
      actual="$("$bin" --version 2>/dev/null | head -n 1 | awk '{print $2}' || true)"
      ;;
  esac
  if [[ "$actual" != "$expected" ]]; then
    echo "$name version mismatch: expected $expected, found ${actual:-unavailable}" >&2
    return 1
  fi
  return 0
}

check_checksum_metadata() {
  local name="$1" bin="$2"
  local marker="$TOOLS_DIR/.$name.sha256" expected_archive
  if [[ ! -f "$marker" ]]; then
    echo "Missing checksum metadata: $marker" >&2
    return 1
  fi
  expected_archive="$(expected_archive_checksum "$name" 2>/dev/null || true)"
  if [[ -z "$expected_archive" ]]; then
    echo "Unable to determine expected archive checksum for $name on $os/$arch" >&2
    return 1
  fi
  if [[ "$(awk -F= '$1 == "archive" { print $2; exit }' "$marker")" != "$expected_archive" ]]; then
    echo "$name archive checksum metadata does not match the pinned release" >&2
    return 1
  fi
  local recorded_binary
  recorded_binary="$(awk -F= '$1 == "binary" { print $2; exit }' "$marker")"
  if [[ -z "$recorded_binary" || ! -f "$bin" || "$recorded_binary" != "$(sha256_file "$bin")" ]]; then
    echo "$name binary checksum metadata does not match the installed binary" >&2
    return 1
  fi
  return 0
}

check_tools() {
  local failures=0
  local -a required=(swiftformat swiftlint rg)
  local name bin expected
  for name in "${required[@]}"; do
    case "$name" in
      swiftformat) bin="$TOOLS_DIR/swiftformat"; expected="$SWIFTFORMAT_VERSION" ;;
      swiftlint) bin="$TOOLS_DIR/swiftlint"; expected="$SWIFTLINT_VERSION" ;;
      rg) bin="$TOOLS_DIR/rg"; expected="$RIPGREP_VERSION" ;;
    esac
    if ! check_binary "$name" "$bin" "$expected" || ! check_checksum_metadata "$name" "$bin"; then
      failures=$((failures + 1))
    fi
  done

  if [[ "$os" == darwin ]]; then
    local xcodegen_real_bin="$TOOLS_DIR/xcodegen-$XCODEGEN_VERSION/bin/xcodegen"
    if ! check_binary xcodegen "$TOOLS_DIR/xcodegen" "$XCODEGEN_VERSION" \
      || ! check_binary xcodegen "$xcodegen_real_bin" "$XCODEGEN_VERSION" \
      || ! check_checksum_metadata xcodegen "$xcodegen_real_bin"; then
      failures=$((failures + 1))
    fi
    if ! check_binary xcbeautify "$TOOLS_DIR/xcbeautify" "$XCBEAUTIFY_VERSION" \
      || ! check_checksum_metadata xcbeautify "$TOOLS_DIR/xcbeautify"; then
      failures=$((failures + 1))
    fi
  fi

  if (( failures > 0 )); then
    echo "Pinned CI tool check failed ($failures tool(s))." >&2
    return 1
  fi
  echo "Pinned CI tools verified (versions, executability, and checksums)."
}

if [[ "$mode" == check ]]; then
  check_tools
  exit $?
fi

mkdir -p "$TOOLS_DIR"

install_swiftformat
install_swiftlint
install_xcodegen
install_ripgrep
install_xcbeautify

export PATH="$TOOLS_DIR:$PATH"
echo "CI tools ready: SwiftFormat $($TOOLS_DIR/swiftformat --version), SwiftLint $($TOOLS_DIR/swiftlint version), XcodeGen $($TOOLS_DIR/xcodegen --version 2>/dev/null | awk '{print $NF}' || echo unavailable), ripgrep $($TOOLS_DIR/rg --version | head -n 1), xcbeautify $($TOOLS_DIR/xcbeautify --version 2>/dev/null || echo unavailable)"
