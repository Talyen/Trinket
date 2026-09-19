#!/usr/bin/env bash
# Per-tool installer for xcodegen (sourced by ensure-ci-tools.sh).
install_xcodegen() {
  # XcodeGen writes the committed project, so use a checksummed release rather
  # than whichever Homebrew formula happens to be current on the runner.
  [[ "$os" == "darwin" ]] || return 0

  local bin="$TOOLS_DIR/xcodegen"
  local install_dir="$TOOLS_DIR/xcodegen-$XCODEGEN_VERSION"
  local real_bin="$install_dir/bin/xcodegen"

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

  if trinket_tool_marker_fresh "xcodegen" "$real_bin" "$XCODEGEN_SHA256" \
    && [[ "$("$real_bin" --version 2>/dev/null | awk '{print $NF}' || true)" == "$XCODEGEN_VERSION" ]]; then
    write_xcodegen_wrapper
    return 0
  fi

  local tmpdir archive
  tmpdir="$(mktemp -d)"
  archive="$tmpdir/xcodegen.zip"

  curl -fsSL "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip" -o "$archive"
  trinket_tool_verify_file "$archive" "$XCODEGEN_SHA256" "XcodeGen"

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
  trinket_tool_write_marker "xcodegen" "$real_bin" "$XCODEGEN_SHA256"
}
