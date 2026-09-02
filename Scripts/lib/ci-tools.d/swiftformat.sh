#!/usr/bin/env bash
# Per-tool installer for swiftformat (sourced by ensure-ci-tools.sh).
install_swiftformat() {
  install_zip_tool swiftformat "$SWIFTFORMAT_VERSION" nicklockwood/SwiftFormat --version swiftformat_linux swiftformat
}
