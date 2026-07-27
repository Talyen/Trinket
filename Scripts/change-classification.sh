#!/usr/bin/env bash

# Shared path collection and routing for agent-facing scripts.
#
# This file is sourced by changed-source-summary.sh, verify-changed.sh, and
# agent-context.sh. It intentionally has no set -e/-u so callers retain control
# of shell error handling.

TRINKET_CHANGED_PATHS=()
TRINKET_AUTHORED_PATHS=()
TRINKET_GENERATED_PATHS=()
TRINKET_PACKAGES=()
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

trinket_classify_smoke_target() {
  local path="$1"

  case "$path" in
    Trinket/Features/Battle/*|Trinket/App/PreparedArtworkCache.swift|TrinketUITests/Battle/*)
      # Hand-drag safety is FullUI-only; agents still use the battle load canary.
      trinket_add_smoke_target SmokeBattleTests
      ;;
    Trinket/Features/Collection/*|Trinket/Features/Options/*|Trinket/Features/Shared/*|Trinket/Shared/Detail/*|TrinketUITests/Collection/*)
      trinket_add_smoke_target SmokeCollectionTests
      ;;
    Trinket/Features/Homestead/*|TrinketUITests/Homestead/*)
      trinket_add_smoke_target SmokeHomesteadTests
      # Presentation row/footer contracts live in unit tests, not smoke.
      TRINKET_NEEDS_UNIT=true
      ;;
    Trinket/Shared/AccessibilityID.swift)
      # ID renames can break any surface; run the lean smoke canaries that pin selectors.
      trinket_add_smoke_target SmokePlayTests
      trinket_add_smoke_target SmokeHomesteadTests
      trinket_add_smoke_target SmokeBattleTests
      trinket_add_smoke_target SmokeCollectionTests
      trinket_add_smoke_target SmokeShopTests
      ;;
    Trinket/Features/Play/Shop/*|TrinketUITests/Play/ShopFlowUITests.swift)
      trinket_add_smoke_target SmokeShopTests
      ;;
    Trinket/Features/Play/*|TrinketUITests/Play/*)
      trinket_add_smoke_target SmokePlayTests
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

trinket_classify_path() {
  local path="$1"

  case "$path" in
    Packages/*/Generated/*|Trinket/Assets.xcassets/*|Trinket/Resources/Music/*|Trinket/Resources/SFX/*|Trinket/Resources/Cinematics/*)
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
    ContentManifest/*|Packages/TrinketContent/Sources/TrinketContent/Content/*)
      TRINKET_HAS_CONTENT=true
      TRINKET_NEEDS_CONTENT_GENERATION=true
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
    Packages/TrinketTestSupport/*.swift|Packages/TrinketTestSupport/**/*.swift)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      TRINKET_NEEDS_UNIT=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Trinket/State/*|Trinket/App/*|Trinket/BattleShell/*|TrinketTests/*|Trinket/Audio/*)
      TRINKET_HAS_SWIFT=true
      TRINKET_NEEDS_STYLE=true
      TRINKET_NEEDS_UNIT=true
      TRINKET_AUTHORED_PATHS+=("$path")
      if [[ "$path" == Trinket/Audio/* ]]; then TRINKET_HAS_AUDIO=true; fi
      if [[ "$path" == Trinket/State/* || "$path" == Trinket/App/* || "$path" == Trinket/BattleShell/* ]]; then TRINKET_HAS_APP_STATE=true; fi
      if [[ "$path" == Trinket/App/PreparedArtworkCache.swift ]]; then
        TRINKET_NEEDS_SMOKE=true
        TRINKET_HAS_FEATURE=true
        trinket_classify_smoke_target "$path"
      fi
      ;;
    Docs/*|*.md|Scripts/*|.github/*)
      TRINKET_HAS_DOCS_OR_TOOLS=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Trinket/Features/*|Trinket/Shared/*|Trinket/Models/*|TrinketUITests/*)
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
    Packages/*)
      trinket_add_boundary_warning "Packages must not import the Trinket app or feature views; keep package dependencies within the package layer."
      ;;
    Trinket/BattleShell/*)
      trinket_add_boundary_warning "BattleShell must not import Trinket/Features."
      ;;
    Trinket/State/*)
      trinket_add_boundary_warning "State must not import feature views."
      ;;
    Trinket/Models/*)
      trinket_add_boundary_warning "Models must not import State or Features."
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
    trinket_add_verification test style "./Scripts/test.sh style"
  fi
  if (( ${#TRINKET_PACKAGES[@]} > 0 )); then
    for package in "${TRINKET_PACKAGES[@]}"; do
      trinket_add_verification package "$package" "./Scripts/test-package.sh $package"
    done
  fi
  # App compile gap-fill: Features/Shared/Models set NEEDS_SMOKE even when no
  # SmokeClass resolves, which used to leave style-only plans that miss Swift 6
  # concurrency / Testing-macro compile errors. build.sh is compile-only
  # (generic simulator destination, no boot) and does not expand smoke.
  # Skip scheduling when unit or a resolved smoke target already compiles the app.
  if [[ "$TRINKET_HAS_FEATURE" == true && "$TRINKET_NEEDS_UNIT" != true ]] \
    && (( ${#TRINKET_SMOKE_TARGETS[@]} == 0 )); then
    if command -v xcodebuild >/dev/null 2>&1; then
      trinket_add_verification build app "SKIP_GENERATE=1 ./Scripts/build.sh"
    else
      TRINKET_APP_COMPILE_SKIPPED_NO_XCODE=true
    fi
  fi
  if [[ "$TRINKET_NEEDS_UNIT" == true ]]; then
    trinket_add_verification test unit "SKIP_GENERATE=1 ./Scripts/test.sh unit"
  fi
  if [[ "$TRINKET_NEEDS_SMOKE" == true ]]; then
    local smoke_target
    if (( ${#TRINKET_SMOKE_TARGETS[@]} > 0 )); then
      for smoke_target in "${TRINKET_SMOKE_TARGETS[@]}"; do
        if [[ "$smoke_target" =~ ^[A-Za-z0-9_]+$ ]]; then
          trinket_add_verification test "smoke:$smoke_target" "SKIP_GENERATE=1 ./Scripts/test.sh smoke $smoke_target"
        else
          TRINKET_SMOKE_TARGET_UNRESOLVED=true
        fi
      done
    fi
  fi
}
