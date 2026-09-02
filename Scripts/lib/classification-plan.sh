#!/usr/bin/env bash

# Verification-plan builder for change-classification.sh.
#
# Sourced by change-classification.sh (which is itself sourced by handoff.sh,
# agent-context.sh, and agent-push-gate.sh). This file intentionally has no
# set -e/-u so callers retain control of shell error handling.
#
# trinket_build_verification_plan reads the TRINKET_* classification state
# (TRINKET_NEEDS_*, TRINKET_HAS_*, TRINKET_PACKAGES, TRINKET_SMOKE_TARGETS,
# TRINKET_AUTHORED_PATHS, TRINKET_CHANGED_PATHS) and fills the
# TRINKET_VERIFICATION_COMMANDS / TRINKET_VERIFICATION_KINDS /
# TRINKET_VERIFICATION_ARGS plan plus the TRINKET_APP_COMPILE_SKIPPED_NO_XCODE
# and TRINKET_SMOKE_TARGET_UNRESOLVED gap-fill flags.

trinket_build_verification_plan() {
  TRINKET_VERIFICATION_COMMANDS=()
  TRINKET_VERIFICATION_KINDS=()
  TRINKET_VERIFICATION_ARGS=()

  if [[ "$TRINKET_NEEDS_ASSET_GENERATION" == true ]]; then
    trinket_add_verification generate assets "./Scripts/generate.sh --assets"
  elif [[ "$TRINKET_NEEDS_CONTENT_GENERATION" == true || "$TRINKET_NEEDS_PROJECT_GENERATION" == true ]]; then
    trinket_add_verification generate normal "./Scripts/generate.sh"
  fi
  if [[ "$TRINKET_NEEDS_CONTENT_GENERATION" == true || "$TRINKET_NEEDS_ASSET_GENERATION" == true || "$TRINKET_NEEDS_PROJECT_GENERATION" == true ]]; then
    if [[ "$TRINKET_NEEDS_ASSET_GENERATION" == true ]]; then
      trinket_add_verification assert idempotent-assets "./Scripts/assert-generated-output.sh --idempotent --assets"
    else
      trinket_add_verification assert idempotent "./Scripts/assert-generated-output.sh --idempotent"
    fi
  fi
  if [[ "$TRINKET_NEEDS_STYLE" == true ]]; then
    local style_swift=()
    local authored
    for authored in "${TRINKET_AUTHORED_PATHS[@]+"${TRINKET_AUTHORED_PATHS[@]}"}"; do
      if [[ "$authored" == *.swift && -f "$authored" ]]; then
        style_swift+=("$authored")
      fi
    done
    local style_scope_needs_full_tree=false
    for authored in "${TRINKET_AUTHORED_PATHS[@]+"${TRINKET_AUTHORED_PATHS[@]}"}"; do
      case "$authored" in
        .swiftlint.yml|.swiftformat|Scripts/tool-versions.env|Scripts/swift-source-dirs.env) style_scope_needs_full_tree=true; break ;;
      esac
    done
    if [[ "$style_scope_needs_full_tree" == false ]]; then
      for authored in "${TRINKET_CHANGED_PATHS[@]+"${TRINKET_CHANGED_PATHS[@]}"}"; do
        case "$authored" in
          Scripts/*|.github/*) style_scope_needs_full_tree=true; break ;;
        esac
      done
    fi
    if [[ "$style_scope_needs_full_tree" == true ]]; then
      trinket_add_verification test style "./Scripts/test.sh style"
    elif (( ${#style_swift[@]} > 0 )); then
      trinket_add_verification test "style:${style_swift[*]}" "./Scripts/test.sh style ${style_swift[*]}"
    else
      trinket_add_verification test style "./Scripts/test.sh style"
    fi
  fi
  if [[ "$TRINKET_NEEDS_SCRIPT_TESTS" == true ]]; then
    trinket_add_verification scripts all "./Scripts/test-scripts.sh"
  fi
  if [[ "$TRINKET_NEEDS_DOCS" == true ]]; then
    trinket_add_verification docs check "python3 ./Scripts/check-docs.py"
  fi
  if (( ${#TRINKET_PACKAGES[@]} > 0 )); then
    trinket_add_verification package "${TRINKET_PACKAGES[*]}" "./Scripts/test-package.sh ${TRINKET_PACKAGES[*]}"
  fi
  # App compile proof: feature/shared Swift diffs get a fast headless compile
  # proof when smoke is not enabled or when no smoke owner is resolved.
  if [[ "$TRINKET_HAS_FEATURE" == true && "$TRINKET_NEEDS_APP_BUILD" != true ]] \
    && { (( ${#TRINKET_SMOKE_TARGETS[@]} == 0 )) || [[ "${TRINKET_ENABLE_SMOKE:-false}" != "true" ]]; }; then
    if command -v xcodebuild >/dev/null 2>&1; then
      trinket_add_verification build app "SKIP_GENERATE=1 ./Scripts/build.sh"
    else
      TRINKET_APP_COMPILE_SKIPPED_NO_XCODE=true
    fi
  fi
  if [[ "$TRINKET_NEEDS_APP_BUILD" == true ]]; then
    if command -v xcodebuild >/dev/null 2>&1; then
      trinket_add_verification build app "SKIP_GENERATE=1 ./Scripts/build.sh"
    else
      TRINKET_APP_COMPILE_SKIPPED_NO_XCODE=true
    fi
  fi
  if [[ "$TRINKET_NEEDS_SMOKE" == true && "${TRINKET_ENABLE_SMOKE:-false}" == "true" ]]; then
    local smoke_target
    local smoke_list=()
    for smoke_target in "${TRINKET_SMOKE_TARGETS[@]+"${TRINKET_SMOKE_TARGETS[@]}"}"; do
      if [[ "$smoke_target" =~ ^[A-Za-z0-9_]+$ ]]; then
        smoke_list+=("$smoke_target")
      else
        TRINKET_SMOKE_TARGET_UNRESOLVED=true
      fi
    done
    if (( ${#smoke_list[@]} > 0 )); then
      trinket_add_verification test "smoke:${smoke_list[*]}" "SKIP_GENERATE=1 ./Scripts/test.sh smoke ${smoke_list[*]}"
    fi
  fi
}
