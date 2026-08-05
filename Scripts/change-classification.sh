#!/usr/bin/env bash

# Shared path collection and routing for agent-facing scripts.
#
# This file is sourced by changed-source-summary.sh, verify-changed.sh, and
# agent-context.sh. It intentionally has no set -e/-u so callers retain control
# of shell error handling.

TRINKET_CHANGE_CLASSIFICATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TRINKET_CHANGED_PATHS=()
TRINKET_AUTHORED_PATHS=()
TRINKET_GENERATED_PATHS=()
TRINKET_PACKAGES=()
TRINKET_BUILD_ONLY_PACKAGES=()
TRINKET_CONTEXT_CARDS=()
TRINKET_SKILLS=()
TRINKET_AGENT_GUIDES=()
TRINKET_BOUNDARY_WARNINGS=()
TRINKET_GENERATED_WARNINGS=()
TRINKET_VERIFICATION_COMMANDS=()
TRINKET_VERIFICATION_KINDS=()
TRINKET_VERIFICATION_ARGS=()
TRINKET_SMOKE_TARGETS=()

TRINKET_HAS_CONTENT=false
TRINKET_HAS_ASSETS=false
TRINKET_HAS_PROJECT=false
TRINKET_HAS_SWIFT=false
TRINKET_HAS_APP_STATE=false
TRINKET_HAS_FEATURE=false
TRINKET_HAS_AUDIO=false
TRINKET_HAS_DOCS_OR_TOOLS=false

TRINKET_NEEDS_CONTENT_GENERATION=false
TRINKET_NEEDS_ASSET_GENERATION=false
TRINKET_NEEDS_PROJECT_GENERATION=false
TRINKET_NEEDS_STYLE=false
TRINKET_NEEDS_UNIT=false
TRINKET_NEEDS_SMOKE=false
# True when feature/shared/model Swift would need app compile but xcodebuild is absent.
TRINKET_APP_COMPILE_SKIPPED_NO_XCODE=false
TRINKET_SMOKE_TARGET_UNRESOLVED=false

trinket_add_unique() {
  local array_name="$1"
  local candidate="$2"
  local item
  local count
  eval "count=\${#$array_name[@]}"
  if (( count > 0 )); then
    eval "for item in \"\${${array_name}[@]}\"; do
      if [[ \"\$item\" == \"\$candidate\" ]]; then return 0; fi
    done"
  fi
  eval "${array_name}+=(\"\$candidate\")"
}

trinket_add_package() { trinket_add_unique TRINKET_PACKAGES "$1"; }
trinket_add_build_only_package() { trinket_add_unique TRINKET_BUILD_ONLY_PACKAGES "$1"; }
trinket_add_context_card() { trinket_add_unique TRINKET_CONTEXT_CARDS "$1"; }
trinket_add_skill() { trinket_add_unique TRINKET_SKILLS "$1"; }
trinket_add_agent_guide() { trinket_add_unique TRINKET_AGENT_GUIDES "$1"; }
trinket_add_boundary_warning() { trinket_add_unique TRINKET_BOUNDARY_WARNINGS "$1"; }
trinket_add_generated_warning() { trinket_add_unique TRINKET_GENERATED_WARNINGS "$1"; }
trinket_add_verification() {
  local kind="$1"
  local argument="$2"
  local display="$3"
  local index
  for index in "${!TRINKET_VERIFICATION_COMMANDS[@]}"; do
    if [[ "${TRINKET_VERIFICATION_COMMANDS[$index]}" == "$display" ]]; then
      return 0
    fi
  done
  TRINKET_VERIFICATION_COMMANDS+=("$display")
  TRINKET_VERIFICATION_KINDS+=("$kind")
  TRINKET_VERIFICATION_ARGS+=("$argument")
}
trinket_add_smoke_target() { trinket_add_unique TRINKET_SMOKE_TARGETS "$1"; }

trinket_remove_smoke_target() {
  local target="$1"
  local filtered=()
  local existing
  for existing in "${TRINKET_SMOKE_TARGETS[@]+"${TRINKET_SMOKE_TARGETS[@]}"}"; do
    if [[ "$existing" != "$target" ]]; then
      filtered+=("$existing")
    fi
  done
  TRINKET_SMOKE_TARGETS=("${filtered[@]+"${filtered[@]}"}")
  if (( ${#TRINKET_SMOKE_TARGETS[@]} == 0 )); then
    TRINKET_NEEDS_SMOKE=false
  fi
}

trinket_collect_paths() {
  local path_mode="${1:-working-tree}"
  shift || true
  TRINKET_CHANGED_PATHS=()

  while IFS= read -r path; do
    [[ -n "$path" ]] && TRINKET_CHANGED_PATHS+=("$path")
  done < <(
    if [[ "$path_mode" == "explicit" ]]; then
      printf '%s\n' "$@" | sed 's#^\./##' | sort -u
    else
      {
        git diff --name-only --diff-filter=ACMRD HEAD
        git ls-files --others --exclude-standard
      } | sort -u
    fi
  )
}

trinket_reset_classification() {
  TRINKET_AUTHORED_PATHS=()
  TRINKET_GENERATED_PATHS=()
  TRINKET_PACKAGES=()
  TRINKET_BUILD_ONLY_PACKAGES=()
  TRINKET_CONTEXT_CARDS=()
  TRINKET_SKILLS=()
  TRINKET_AGENT_GUIDES=()
  TRINKET_BOUNDARY_WARNINGS=()
  TRINKET_GENERATED_WARNINGS=()
  TRINKET_VERIFICATION_COMMANDS=()
  TRINKET_VERIFICATION_KINDS=()
  TRINKET_VERIFICATION_ARGS=()
  TRINKET_SMOKE_TARGETS=()

  TRINKET_HAS_CONTENT=false
  TRINKET_HAS_ASSETS=false
  TRINKET_HAS_PROJECT=false
  TRINKET_HAS_SWIFT=false
  TRINKET_HAS_APP_STATE=false
  TRINKET_HAS_FEATURE=false
  TRINKET_HAS_AUDIO=false
  TRINKET_HAS_DOCS_OR_TOOLS=false

  TRINKET_NEEDS_CONTENT_GENERATION=false
  TRINKET_NEEDS_ASSET_GENERATION=false
  TRINKET_NEEDS_PROJECT_GENERATION=false
  TRINKET_NEEDS_STYLE=false
  TRINKET_NEEDS_UNIT=false
  TRINKET_NEEDS_SMOKE=false
  TRINKET_APP_COMPILE_SKIPPED_NO_XCODE=false
  TRINKET_SMOKE_TARGET_UNRESOLVED=false
}

trinket_is_battle_feature_debug_lab() {
  local path="$1"
  case "$path" in
    *Lab*.swift|*Playground*.swift|*EffectVariants.swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

trinket_is_play_smoke_shell_path() {
  local path="$1"
  case "$path" in
    Trinket/Features/Play/PlayView.swift|Trinket/Features/Play/Modes/ExploreHub*|Trinket/Features/Play/Modes/SpiresHub*|Trinket/Features/Play/Modes/PlayModeHub*|TrinketUITests/Play/PlayFlowUITests.swift|TrinketUITests/Smoke/SmokePlayTests.swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

trinket_classify_smoke_target() {
  local path="$1"

  case "$path" in
    Packages/TrinketBattleFeature/Sources/*|TrinketUITests/Battle/*)
      if trinket_is_battle_feature_debug_lab "$path"; then
        return 0
      fi
      # Hand-drag safety is FullUI-only; agents still use the battle load canary.
      trinket_add_smoke_target SmokeBattleTests
      ;;
    Trinket/Features/Collection/*|TrinketUITests/Collection/*)
      trinket_add_smoke_target SmokeCollectionTests
      ;;
    Trinket/Features/Homestead/*|TrinketUITests/Homestead/*)
      trinket_add_smoke_target SmokeHomesteadTests
      # Presentation row/footer contracts live in unit tests, not smoke.
      TRINKET_NEEDS_UNIT=true
      ;;
    Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/AccessibilityID.swift)
      # Local canary only; PR smoke-full covers the five-surface matrix.
      trinket_add_smoke_target SmokeHomesteadTests
      ;;
    Trinket/Features/Play/Shop/*|TrinketUITests/Play/ShopFlowUITests.swift)
      trinket_add_smoke_target SmokeShopTests
      ;;
    Trinket/Features/Play/*|TrinketUITests/Play/*)
      # SmokePlayTests only asserts Play mode-card shell. Subflows without a
      # smoke owner (Mystery, Labyrinth, StagePreview, …) stay compile-only.
      # PlayView.swift is whitelisted here; subflow-only diffs demote later via
      # trinket_apply_play_shell_smoke_demotion.
      if trinket_is_play_smoke_shell_path "$path"; then
        trinket_add_smoke_target SmokePlayTests
      fi
      ;;
    TrinketUITests/Smoke/*.swift)
      local target="${path##*/}"
      trinket_add_smoke_target "${target%.swift}"
      ;;
    TrinketUITests/Support/*)
      trinket_add_smoke_target SmokeHomesteadTests
      ;;
    *)
      TRINKET_SMOKE_TARGET_UNRESOLVED=true
      ;;
  esac
}

# Demote SmokePlayTests when PlayView.swift diffs are only subflow/cover wiring
# (not mode-card shell) and no other Play shell whitelist path is in the set.
# Fail-closed via Scripts/classify-play-shell-diff.py.
trinket_apply_play_shell_smoke_demotion() {
  local authored
  local has_play_view=false
  local has_other_shell=false
  local assessment

  for authored in "${TRINKET_AUTHORED_PATHS[@]+"${TRINKET_AUTHORED_PATHS[@]}"}"; do
    case "$authored" in
      Trinket/Features/Play/PlayView.swift)
        has_play_view=true
        ;;
      Trinket/Features/Play/Modes/ExploreHub*|Trinket/Features/Play/Modes/SpiresHub*|Trinket/Features/Play/Modes/PlayModeHub*|TrinketUITests/Play/PlayFlowUITests.swift|TrinketUITests/Smoke/SmokePlayTests.swift)
        has_other_shell=true
        ;;
    esac
  done

  [[ "$has_play_view" == true ]] || return 0
  [[ "$has_other_shell" == true ]] && return 0

  local has_play_smoke=false
  local target
  for target in "${TRINKET_SMOKE_TARGETS[@]+"${TRINKET_SMOKE_TARGETS[@]}"}"; do
    if [[ "$target" == "SmokePlayTests" ]]; then
      has_play_smoke=true
      break
    fi
  done
  [[ "$has_play_smoke" == true ]] || return 0

  assessment="$(
    python3 "$TRINKET_CHANGE_CLASSIFICATION_DIR/classify-play-shell-diff.py" \
      "Trinket/Features/Play/PlayView.swift"
  )" || assessment="uncertain"
  [[ "$assessment" == "subflow" ]] || return 0

  trinket_remove_smoke_target SmokePlayTests
}

# Demote package tests + smoke to compile-only when every authored Swift diff is
# presentation chrome (metrics/copy/SF Symbol/modifiers). Fail-closed via
# Scripts/classify-presentation-only.py — uncertain diffs keep full routing.
trinket_apply_presentation_only_demotion() {
  local swift_paths=()
  local authored
  local assessment
  local package

  for authored in "${TRINKET_AUTHORED_PATHS[@]+"${TRINKET_AUTHORED_PATHS[@]}"}"; do
    if [[ "$authored" == *.swift ]]; then
      swift_paths+=("$authored")
    fi
  done
  (( ${#swift_paths[@]} > 0 )) || return 0

  assessment="$(
    python3 "$TRINKET_CHANGE_CLASSIFICATION_DIR/classify-presentation-only.py" \
      "${swift_paths[@]}"
  )" || assessment="behavioral"
  [[ "$assessment" == "presentation-only" ]] || return 0

  # App compile covers package products when a feature path already schedules
  # build.sh; otherwise keep a package build-only compile check.
  if (( ${#TRINKET_PACKAGES[@]} > 0 )) && [[ "$TRINKET_HAS_FEATURE" != true ]]; then
    for package in "${TRINKET_PACKAGES[@]}"; do
      trinket_add_build_only_package "$package"
    done
  fi
  TRINKET_PACKAGES=()
  TRINKET_SMOKE_TARGETS=()
  TRINKET_NEEDS_SMOKE=false
  # Homestead presentation-only chrome should not pay app unit either.
  if [[ "$TRINKET_NEEDS_UNIT" == true && "$TRINKET_HAS_FEATURE" == true ]]; then
    TRINKET_NEEDS_UNIT=false
  fi
}

# When every touched TrinketBattleFeature Swift path is a DEBUG lab/playground/
# EffectVariants file, demote full package tests to --build-only. CI `unit`
# already runs the BattleFeature suite; local keeps compile proof only.
# Shipping BattleFeature paths (non-lab) keep full package tests + smoke.
trinket_apply_battle_feature_lab_demotion() {
  local authored
  local battle_feature_swift=()
  local path
  local has_lab=false
  local has_shipping=false
  local filtered=()
  local package
  local in_full_packages=false

  for package in "${TRINKET_PACKAGES[@]+"${TRINKET_PACKAGES[@]}"}"; do
    if [[ "$package" == "TrinketBattleFeature" ]]; then
      in_full_packages=true
      break
    fi
  done
  [[ "$in_full_packages" == true ]] || return 0

  for authored in "${TRINKET_AUTHORED_PATHS[@]+"${TRINKET_AUTHORED_PATHS[@]}"}"; do
    if [[ "$authored" == Packages/TrinketBattleFeature/* && "$authored" == *.swift ]]; then
      battle_feature_swift+=("$authored")
    fi
  done
  (( ${#battle_feature_swift[@]} > 0 )) || return 0

  for path in "${battle_feature_swift[@]}"; do
    if trinket_is_battle_feature_debug_lab "$path"; then
      has_lab=true
    else
      has_shipping=true
    fi
  done
  [[ "$has_lab" == true && "$has_shipping" == false ]] || return 0

  for package in "${TRINKET_PACKAGES[@]}"; do
    if [[ "$package" != "TrinketBattleFeature" ]]; then
      filtered+=("$package")
    fi
  done
  TRINKET_PACKAGES=("${filtered[@]+"${filtered[@]}"}")
  trinket_add_build_only_package TrinketBattleFeature
}

trinket_classify_path() {
  local path="$1"

  case "$path" in
    Packages/*/Generated/*|Trinket/Assets.xcassets/*|Trinket/Media/Music/*|Trinket/Media/SFX/*|Trinket/Media/Cinematics/*)
      TRINKET_GENERATED_PATHS+=("$path")
      if [[ "$path" == Packages/*/Generated/* ]]; then
        case "$path" in
          Packages/*/Generated/*SourceHashes.generated.tsv)
            TRINKET_NEEDS_ASSET_GENERATION=true
            trinket_add_generated_warning "Generated asset hash state detected; edit the manifest/raw asset source and run ./Scripts/generate.sh --assets."
            ;;
          *)
            TRINKET_NEEDS_CONTENT_GENERATION=true
            trinket_add_generated_warning "Generated package output detected; edit the authored source and run ./Scripts/generate.sh."
            ;;
        esac
      else
        TRINKET_NEEDS_ASSET_GENERATION=true
        trinket_add_generated_warning "Processed app output detected; edit the manifest/raw asset source and run the appropriate generation command."
      fi
      ;;
    ContentManifest/*)
      TRINKET_HAS_CONTENT=true
      TRINKET_NEEDS_CONTENT_GENERATION=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Packages/TrinketContent/Sources/TrinketContent/Content/*.swift)
      TRINKET_HAS_CONTENT=true
      TRINKET_NEEDS_CONTENT_GENERATION=true
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      trinket_add_package TrinketContent
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    ArtManifest/*|MusicManifest/*|SoundManifest/*|CinematicManifest/*|Raw\ Assets/*)
      TRINKET_HAS_ASSETS=true
      TRINKET_NEEDS_ASSET_GENERATION=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Scripts/prepare-art-assets.sh|Scripts/prepare-music-assets.sh|Scripts/prepare-sfx-assets.sh|Scripts/prepare-cinematic-assets.sh|Scripts/prepare-app-icon.sh)
      TRINKET_HAS_ASSETS=true
      TRINKET_NEEDS_ASSET_GENERATION=true
      TRINKET_HAS_DOCS_OR_TOOLS=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    project.yml)
      TRINKET_HAS_PROJECT=true
      TRINKET_NEEDS_PROJECT_GENERATION=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Packages/BattleEngine/*.swift|Packages/BattleEngine/**/*.swift)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      trinket_add_package BattleEngine
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Packages/TrinketContent/*.swift|Packages/TrinketContent/**/*.swift)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      trinket_add_package TrinketContent
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Packages/TrinketPersistence/*.swift|Packages/TrinketPersistence/**/*.swift)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      trinket_add_package TrinketPersistence
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Packages/TrinketCore/*.swift|Packages/TrinketCore/**/*.swift)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      trinket_add_package TrinketCore
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Packages/TrinketDesignSystem/*.swift|Packages/TrinketDesignSystem/**/*.swift)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      trinket_add_package TrinketDesignSystem
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Packages/TrinketFeatureSupport/*.swift|Packages/TrinketFeatureSupport/**/*.swift)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      trinket_add_package TrinketFeatureSupport
      TRINKET_AUTHORED_PATHS+=("$path")
      if [[ "$path" == Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/AccessibilityID.swift ]]; then
        TRINKET_NEEDS_SMOKE=true
        trinket_classify_smoke_target "$path"
      elif [[ "$path" == Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift ]]; then
        TRINKET_NEEDS_SMOKE=true
        trinket_add_smoke_target SmokeBattleTests
      fi
      ;;
    Packages/TrinketBattleRuntime/*.swift|Packages/TrinketBattleRuntime/**/*.swift)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      trinket_add_package TrinketBattleRuntime
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Packages/TrinketBattleFeature/*.swift|Packages/TrinketBattleFeature/**/*.swift)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      trinket_add_package TrinketBattleFeature
      TRINKET_AUTHORED_PATHS+=("$path")
      if trinket_is_battle_feature_debug_lab "$path"; then
        # DEBUG labs: local compile-only (--build-only after demotion); CI unit
        # owns the full BattleFeature package suite / smoke / app compile.
        :
      else
        TRINKET_NEEDS_SMOKE=true
        TRINKET_HAS_FEATURE=true
        trinket_classify_smoke_target "$path"
      fi
      ;;
    Packages/TrinketAppState/*.swift|Packages/TrinketAppState/**/*.swift)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      TRINKET_HAS_APP_STATE=true
      trinket_add_package TrinketAppState
      TRINKET_AUTHORED_PATHS+=("$path")
      if [[ "$path" == Packages/TrinketAppState/Sources/TrinketAppState/Audio/* ]]; then
        TRINKET_HAS_AUDIO=true
      fi
      ;;
    Packages/TrinketTestSupport/*.swift|Packages/TrinketTestSupport/**/*.swift)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      TRINKET_NEEDS_UNIT=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Trinket/App/*|TrinketTests/*)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      TRINKET_NEEDS_UNIT=true
      TRINKET_AUTHORED_PATHS+=("$path")
      if [[ "$path" == Trinket/App/* ]]; then TRINKET_HAS_APP_STATE=true; fi
      ;;
    Docs/*|*.md|Scripts/*|.github/*)
      TRINKET_HAS_DOCS_OR_TOOLS=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Trinket/Features/*|TrinketUITests/*)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      TRINKET_NEEDS_SMOKE=true
      TRINKET_HAS_FEATURE=true
      TRINKET_AUTHORED_PATHS+=("$path")
      trinket_classify_smoke_target "$path"
      ;;
    *.swift)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    project.pbxproj|*/project.pbxproj)
      trinket_add_boundary_warning "project.pbxproj is generated/protected; edit project.yml and run ./Scripts/generate.sh instead."
      TRINKET_NEEDS_PROJECT_GENERATION=true
      TRINKET_NEEDS_CONTENT_GENERATION=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    *)
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
  esac

  case "$path" in
    Packages/TrinketDesignSystem/*)
      trinket_add_boundary_warning "TrinketDesignSystem may depend on TrinketCore only; keep app, BattleEngine, and TrinketContent imports out."
      ;;
    Packages/TrinketFeatureSupport/*)
      trinket_add_boundary_warning "TrinketFeatureSupport must stay below TrinketBattleFeature and TrinketAppState in the package DAG."
      ;;
    Packages/TrinketBattleFeature/*)
      trinket_add_boundary_warning "TrinketBattleFeature must not import or depend on TrinketAppState."
      ;;
    Packages/*)
      trinket_add_boundary_warning "Packages must not import the Trinket app; keep dependencies within the enforced package DAG."
      ;;
  esac
}

trinket_classify_paths() {
  trinket_reset_classification
  local path
  if (( ${#TRINKET_CHANGED_PATHS[@]} > 0 )); then
    for path in "${TRINKET_CHANGED_PATHS[@]}"; do
      trinket_classify_path "$path"
    done
  fi

  trinket_apply_presentation_only_demotion
  trinket_apply_battle_feature_lab_demotion
  trinket_apply_play_shell_smoke_demotion

  if [[ "$TRINKET_NEEDS_ASSET_GENERATION" == true ]]; then
    TRINKET_NEEDS_CONTENT_GENERATION=true
  fi
  if [[ "$TRINKET_NEEDS_PROJECT_GENERATION" == true ]]; then
    TRINKET_NEEDS_CONTENT_GENERATION=true
  fi

  if [[ "$TRINKET_HAS_CONTENT" == true || "$TRINKET_HAS_ASSETS" == true ]]; then
    trinket_add_context_card Docs/AgentContext/content-and-manifests.md
  fi
  if (( ${#TRINKET_PACKAGES[@]} > 0 )); then
    for package in "${TRINKET_PACKAGES[@]}"; do
      case "$package" in
        BattleEngine) trinket_add_context_card Docs/AgentContext/battle.md ;;
        TrinketPersistence) trinket_add_context_card Docs/AgentContext/persistence.md ;;
        TrinketBattleFeature) trinket_add_context_card Docs/AgentContext/battle.md ;;
        TrinketFeatureSupport)
          trinket_add_context_card Docs/AgentContext/swiftui-features.md
          trinket_add_skill Docs/Skills/apple-design/SKILL.md
          ;;
      esac
    done
  fi
  if [[ "$TRINKET_HAS_FEATURE" == true ]]; then
    trinket_add_context_card Docs/AgentContext/swiftui-features.md
    trinket_add_skill Docs/Skills/apple-design/SKILL.md
  fi
  if [[ "$TRINKET_HAS_AUDIO" == true ]]; then
    trinket_add_context_card Docs/AgentContext/audio.md
  fi
  if [[ "$TRINKET_HAS_PROJECT" == true ]]; then
    trinket_add_context_card Docs/AgentContext/ci-and-project-generation.md
  else
    for path in "${TRINKET_CHANGED_PATHS[@]}"; do
      case "$path" in
        Scripts/*|.github/*)
          trinket_add_context_card Docs/AgentContext/ci-and-project-generation.md
          break
          ;;
      esac
    done
  fi

  if (( ${#TRINKET_CHANGED_PATHS[@]} > 0 )); then
    for path in "${TRINKET_CHANGED_PATHS[@]}"; do
      trinket_add_agent_guides_for_path "$path"
    done
  fi
}

trinket_add_agent_guides_for_path() {
  local path="$1"
  local directory="$path"
  local parent
  [[ "$directory" == */* ]] && directory="${directory%/*}" || directory=""
  while [[ -n "$directory" ]]; do
    if [[ -f "$directory/AGENTS.md" ]]; then
      trinket_add_agent_guide "$directory/AGENTS.md"
    fi
    parent="${directory%/*}"
    [[ "$parent" == "$directory" ]] && break
    directory="$parent"
  done
}

trinket_build_verification_plan() {
  TRINKET_VERIFICATION_COMMANDS=()
  TRINKET_VERIFICATION_KINDS=()
  TRINKET_VERIFICATION_ARGS=()

  local push_ready="${TRINKET_PUSH_READY:-false}"

  if [[ "$push_ready" == true ]]; then
    # Commit completeness: regenerate with pinned XcodeGen (force), then assert vs HEAD.
    # Task-scoped verify keeps --idempotent so uncommitted generation remains OK.
    if [[ "$TRINKET_NEEDS_ASSET_GENERATION" == true ]]; then
      trinket_add_verification generate assets-force "./Scripts/generate.sh --assets --force-xcodegen"
      trinket_add_verification assert assets "./Scripts/assert-generated-output.sh --assets"
    else
      trinket_add_verification generate force "./Scripts/generate.sh --force-xcodegen"
      trinket_add_verification assert committed "./Scripts/assert-generated-output.sh"
    fi
  else
    if [[ "$TRINKET_NEEDS_ASSET_GENERATION" == true ]]; then
      trinket_add_verification generate assets "./Scripts/generate.sh --assets"
    elif [[ "$TRINKET_NEEDS_CONTENT_GENERATION" == true || "$TRINKET_NEEDS_PROJECT_GENERATION" == true ]]; then
      trinket_add_verification generate normal "./Scripts/generate.sh"
    fi
    if [[ "$TRINKET_NEEDS_CONTENT_GENERATION" == true || "$TRINKET_NEEDS_ASSET_GENERATION" == true || "$TRINKET_NEEDS_PROJECT_GENERATION" == true ]]; then
      if [[ "$TRINKET_NEEDS_ASSET_GENERATION" == true ]]; then
        # Idempotent: confirm regenerate is a no-op. Do not assert vs HEAD — that is
        # CI/pre-push/agent-push-gate commit-completeness (intentional uncommitted generation is fine here).
        trinket_add_verification assert idempotent-assets "./Scripts/assert-generated-output.sh --idempotent --assets"
      else
        trinket_add_verification assert idempotent "./Scripts/assert-generated-output.sh --idempotent"
      fi
    fi
  fi
  # Always run style when Swift changed — format/lint failures do not need a simulator.
  # Package compile stays paired with touched packages (also no simulator required).
  if [[ "$TRINKET_NEEDS_STYLE" == true ]]; then
    local style_swift=()
    local authored
    for authored in "${TRINKET_AUTHORED_PATHS[@]+"${TRINKET_AUTHORED_PATHS[@]}"}"; do
      if [[ "$authored" == *.swift ]]; then
        style_swift+=("$authored")
      fi
    done
    if (( ${#style_swift[@]} > 0 )); then
      # Path-scoped style for verify; ci-gate / bare test.sh style stay full-tree.
      local style_display="./Scripts/test.sh style ${style_swift[*]}"
      local style_arg="style:${style_swift[*]}"
      trinket_add_verification test "$style_arg" "$style_display"
    else
      trinket_add_verification test style "./Scripts/test.sh style"
    fi
  fi
  if (( ${#TRINKET_PACKAGES[@]} > 0 )); then
    # One invocation so packages share sim/destination setup (parallel DD tenants).
    local package_list="${TRINKET_PACKAGES[*]}"
    trinket_add_verification package "$package_list" "./Scripts/test-package.sh $package_list"
  fi
  if (( ${#TRINKET_BUILD_ONLY_PACKAGES[@]} > 0 )); then
    local build_only_list="${TRINKET_BUILD_ONLY_PACKAGES[*]}"
    trinket_add_verification package-build "$build_only_list" \
      "./Scripts/test-package.sh --build-only $build_only_list"
  fi
  # App compile gap-fill: presentation/feature paths can set NEEDS_SMOKE even when no
  # SmokeClass resolves. Avoid style-only plans that miss Swift 6 concurrency /
  # Testing-macro compile errors. build.sh is compile-only
  # (generic simulator destination, no boot) and does not expand smoke.
  # Skip when unit or resolved smoke already compiles the app. Package tests do not
  # compile app feature targets — keep gap-fill even when packages are also scheduled.
  if [[ "$TRINKET_HAS_FEATURE" == true && "$TRINKET_NEEDS_UNIT" != true ]] \
    && (( ${#TRINKET_SMOKE_TARGETS[@]} == 0 )); then
    if command -v xcodebuild >/dev/null 2>&1; then
      trinket_add_verification build app "SKIP_GENERATE=1 ./Scripts/build.sh"
    else
      TRINKET_APP_COMPILE_SKIPPED_NO_XCODE=true
    fi
  fi
  if [[ "$TRINKET_NEEDS_UNIT" == true ]]; then
    # Path-scoped unit is TrinketTests only; packages are scheduled above when touched.
    trinket_add_verification test unit "SKIP_GENERATE=1 ./Scripts/test.sh unit --app-only"
  fi
  if [[ "$TRINKET_NEEDS_SMOKE" == true ]]; then
    local smoke_target
    local smoke_list=()
    if (( ${#TRINKET_SMOKE_TARGETS[@]} > 0 )); then
      for smoke_target in "${TRINKET_SMOKE_TARGETS[@]}"; do
        if [[ "$smoke_target" =~ ^[A-Za-z0-9_]+$ ]]; then
          smoke_list+=("$smoke_target")
        else
          TRINKET_SMOKE_TARGET_UNRESOLVED=true
        fi
      done
    fi
    if (( ${#smoke_list[@]} > 0 )); then
      # One xcodebuild with multiple -only-testing filters (not N process starts).
      local smoke_arg="smoke:${smoke_list[*]}"
      trinket_add_verification test "$smoke_arg" "SKIP_GENERATE=1 ./Scripts/test.sh smoke ${smoke_list[*]}"
    fi
  fi
}
