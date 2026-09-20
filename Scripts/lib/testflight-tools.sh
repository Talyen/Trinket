#!/usr/bin/env bash
# Local release dependencies, separate from ordinary build/CI tooling.
trinket_testflight_tools() {
  local root="$1" install="$2" ruby_prefix
  if ! command -v brew >/dev/null 2>&1; then
    echo "TestFlight tooling needs Homebrew (https://brew.sh), then ./Scripts/setup-testflight.sh." >&2
    return 1
  fi
  ruby_prefix="$(brew --prefix ruby@3.4)"
  if [[ ! -x "$ruby_prefix/bin/ruby" ]]; then
    if [[ "$install" != true ]]; then
      echo "Missing Ruby 3.4. Run ./Scripts/setup-testflight.sh." >&2
      return 1
    fi
    HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew install ruby@3.4
  fi
  export PATH="$ruby_prefix/bin:$PATH"
  export GEM_HOME="$root/.tools/testflight/gems"
  export GEM_PATH="$GEM_HOME"
  export BUNDLE_GEMFILE="$root/Gemfile"
  export BUNDLE_PATH="$root/.tools/testflight/bundle"
  export BUNDLE_FROZEN=true BUNDLE_IGNORE_CONFIG=1
  export FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_HIDE_CHANGELOG=1
  export FASTLANE_OPT_OUT_USAGE=1 FASTLANE_SKIP_DOCS=1
  export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
  TRINKET_BUNDLE="$GEM_HOME/bin/bundle"
  if [[ ! -x "$TRINKET_BUNDLE" ]] || ! "$TRINKET_BUNDLE" _4.0.15_ --version >/dev/null 2>&1; then
    if [[ "$install" != true ]]; then
      echo "Missing Bundler. Run ./Scripts/setup-testflight.sh." >&2
      return 1
    fi
    gem install bundler --version 4.0.15 --no-document
  fi
  if ! "$TRINKET_BUNDLE" _4.0.15_ check >/dev/null 2>&1; then
    if [[ "$install" != true ]]; then
      echo "Missing locked Fastlane dependencies. Run ./Scripts/setup-testflight.sh." >&2
      return 1
    fi
    "$TRINKET_BUNDLE" _4.0.15_ install
  fi
  export TRINKET_BUNDLE
}
