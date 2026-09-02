#!/usr/bin/env bash
# Per-tool installer for swiftlint (sourced by ensure-ci-tools.sh).
install_swiftlint() {
  install_zip_tool swiftlint "$SWIFTLINT_VERSION" realm/SwiftLint version swiftlint-static swiftlint
}
