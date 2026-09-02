#!/usr/bin/env bash
# Per-tool installer for xcbeautify (sourced by ensure-ci-tools.sh).
install_xcbeautify() {
  # Local/darwin only: CI omits --verbose and uses structured failure reports,
  # so a condensed formatter is only needed on mac for the run/build path.
  [[ "$os" == "darwin" ]] || return 0
  install_zip_tool xcbeautify "$XCBEAUTIFY_VERSION" cpisciotta/xcbeautify --version xcbeautify
}
