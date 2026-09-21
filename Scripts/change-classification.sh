#!/usr/bin/env bash

# Shared path collection and routing for agent-facing scripts.
#
# This file is sourced by handoff.sh, agent-context.sh, and agent-push-gate.sh.
# It intentionally has no set -e/-u so callers retain control of shell error
# handling.
#
# This is a deterministic router: given the changed paths it flags which
# generation/style/package/app/unit/smoke checks apply, and which feature/UI
# path owns a targeted smoke canary. It performs no demotions. Path ownership
# is exact-match on location, with three narrow diff-content exceptions:
# doc-budget routing (checker directives added in the diff), architect routing
# (public/schema/boundary symbols declared in the diff), and the visual-UI
# glob for smoke-gap detection. Unowned feature/UI
# diffs fall back to the app-compile gap-fill (trinket_build_verification_plan).

TRINKET_CHANGE_CLASSIFICATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/smoke-classes.sh
source "$TRINKET_CHANGE_CLASSIFICATION_DIR/lib/smoke-classes.sh"
# shellcheck source=build-inputs.env
source "$TRINKET_CHANGE_CLASSIFICATION_DIR/build-inputs.env"
# shellcheck source=lib/classification-plan.sh
source "$TRINKET_CHANGE_CLASSIFICATION_DIR/lib/classification-plan.sh"
# shellcheck source=lib/generated-paths.sh
source "$TRINKET_CHANGE_CLASSIFICATION_DIR/lib/generated-paths.sh"

source "$TRINKET_CHANGE_CLASSIFICATION_DIR/lib/project-generation.sh"

TRINKET_CHANGED_PATHS=()
TRINKET_AUTHORED_PATHS=()
TRINKET_GENERATED_PATHS=()
TRINKET_PACKAGES=()
TRINKET_CONTEXT_CARDS=()
TRINKET_ROUTE_CARDS=()
TRINKET_SKILLS=()
TRINKET_KNOWLEDGE=()
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
TRINKET_HAS_FEATURE=false
TRINKET_HAS_AUDIO=false
TRINKET_HAS_VISUAL_UI=false

TRINKET_NEEDS_CONTENT_GENERATION=false
TRINKET_NEEDS_ASSET_GENERATION=false
TRINKET_NEEDS_PROJECT_GENERATION=false
TRINKET_NEEDS_STYLE=false
TRINKET_NEEDS_APP_BUILD=false
TRINKET_NEEDS_SMOKE=false
TRINKET_NEEDS_SCRIPT_TESTS=false
TRINKET_NEEDS_DOCS=false
# True when feature/shared/model Swift would need app compile but xcodebuild is absent.
TRINKET_APP_COMPILE_SKIPPED_NO_XCODE=false
TRINKET_SMOKE_TARGET_UNRESOLVED=false

trinket_add_unique() {
  local array_name="$1"
  local candidate="$2"
  local item
  local count
  eval "count=\${#${array_name}[@]}"
  if (( count > 0 )); then
    eval "for item in \"\${${array_name}[@]}\"; do
      if [[ \"\$item\" == \"\$candidate\" ]]; then return 0; fi
    done"
  fi
  eval "${array_name}+=(\"\$candidate\")"
}

trinket_add_package() { trinket_add_unique TRINKET_PACKAGES "$1"; }

trinket_package_has_tests() {
  local package="$1"
  local candidate
  for candidate in "${TRINKET_TEST_PACKAGES[@]}"; do
    [[ "$candidate" == "$package" ]] && return 0
  done
  return 1
}

# Consumers that pin shared fixture behavior; fixture source changes fan out
# to all of them (see Scripts/Tests/test_ci_handoff_routing.py).
TRINKET_SHARED_FIXTURE_CONSUMERS=(BattleEngine TrinketAppState TrinketBattleFeature TrinketFeatureSupport)

trinket_route_shared_fixture_verification() {
  local consumer
  for consumer in "${TRINKET_SHARED_FIXTURE_CONSUMERS[@]}"; do
    trinket_add_package "$consumer"
  done
}

# Route touched package diffs to package tests or app compile proof.
trinket_route_package_verification() {
  local package="$1"
  if trinket_package_has_tests "$package"; then
    trinket_add_package "$package"
  else
    TRINKET_NEEDS_APP_BUILD=true
  fi
}
trinket_add_context_card() {
  local card="$1" existing
  local -a retained=()
  for existing in "${TRINKET_CONTEXT_CARDS[@]-}"; do
    # A broad owner in a mixed scope subsumes its section recommendations.
    [[ "$existing" == "${card%%#*}" ]] && return 0
    if [[ "$card" != *'#'* && "$existing" == "$card#"* ]]; then continue; fi
    [[ -n "$existing" ]] && retained+=("$existing")
  done
  TRINKET_CONTEXT_CARDS=()
  if (( ${#retained[@]} > 0 )); then TRINKET_CONTEXT_CARDS=("${retained[@]}"); fi
  trinket_add_unique TRINKET_CONTEXT_CARDS "$card"
}
trinket_add_route_card() { trinket_add_unique TRINKET_ROUTE_CARDS "$1"; }
trinket_add_skill() { trinket_add_unique TRINKET_SKILLS "$1"; }
trinket_add_knowledge() { trinket_add_unique TRINKET_KNOWLEDGE "$1"; }
trinket_add_agent_guide() { trinket_add_unique TRINKET_AGENT_GUIDES "$1"; }

# Every card in Docs/AgentContext/ must be emitted above or declared here as
# lookup-only; Scripts/check-docs.py enforces this. Lazy cards load on demand:
# lookup-only: Docs/AgentContext/ci-diagnostics.md
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

# Presentation taxonomy (behavior-card split, skill triggers, discovery search
# roots) lives in Scripts/agent-context.sh, its sole consumer. Card coverage
# here stays enforced: Scripts/check-docs.py greps this file for every
# Docs/AgentContext/*.md reference, and each behavior card is also emitted by
# a trinket_add_context_card call below.

trinket_classify_package_swift_path() {
  local path="$1"
  local package="${path#Packages/}"
  package="${package%%/*}"

  # Membership gate reads the package registry in Scripts/build-inputs.env
  # (sourced above), not a second hardcoded list.
  local candidate
  local known=false
  for candidate in "${TRINKET_TEST_PACKAGES[@]}"; do
    if [[ "$package" == "$candidate" ]]; then
      known=true
      break
    fi
  done
  [[ "$known" == true ]] || return 1

  TRINKET_NEEDS_STYLE=true
  TRINKET_AUTHORED_PATHS+=("$path")

  case "$package" in
    TrinketDesignSystem)
      if [[ "$path" == Packages/TrinketDesignSystem/Sources/* ]]; then
        trinket_add_skill .agents/skills/apple-design/SKILL.md
      fi
      ;;
    TrinketFeatureSupport)
      if [[ "$path" == Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/AccessibilityID.swift \
         || "$path" == Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift \
         || "$path" == Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtwork.swift ]]; then
        TRINKET_NEEDS_SMOKE=true
        trinket_add_smoke_target_for_path "$path"
      fi
      ;;
    TrinketBattleFeature)
      TRINKET_NEEDS_SMOKE=true
      TRINKET_HAS_FEATURE=true
      trinket_add_smoke_target_for_path "$path"
      ;;
    TrinketAppState)
      if [[ "$path" == Packages/TrinketAppState/Sources/TrinketAppState/Audio/* ]]; then
        TRINKET_HAS_AUDIO=true
        TRINKET_NEEDS_SMOKE=true
        trinket_add_smoke_target "$TRINKET_SMOKE_CLASS_SHELL"
      fi
      ;;
  esac
}

trinket_collect_paths() {
  local path_mode="${1:-working-tree}"
  shift || true
  TRINKET_CHANGED_PATHS=()

  local path
  if [[ "$path_mode" == "explicit" ]]; then
    local normalized
    normalized="$(python3 - "$PWD" "$@" <<'PY_PATHS'
from pathlib import Path
import sys
root = Path(sys.argv[1]).resolve()
for raw in sys.argv[2:]:
    path = (root / raw).resolve()
    try:
        relative = path.relative_to(root)
    except ValueError:
        raise SystemExit(f"--paths must stay within the repository: {raw}")
    if path.is_dir():
        raise SystemExit(f"--paths requires individual files, not directories: {raw}")
    if not raw or "\n" in raw:
        raise SystemExit("--paths requires non-empty single-line paths")
    print(relative.as_posix())
PY_PATHS
)" || return 2
    set --
    while IFS= read -r path; do
      set -- "$@" "$path"
    done <<< "$normalized"
  fi

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
  TRINKET_ROUTE_CARDS=()
  TRINKET_SKILLS=()
  TRINKET_KNOWLEDGE=()
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
  TRINKET_HAS_FEATURE=false
  TRINKET_HAS_AUDIO=false
  TRINKET_HAS_VISUAL_UI=false

  TRINKET_NEEDS_CONTENT_GENERATION=false
  TRINKET_NEEDS_ASSET_GENERATION=false
  TRINKET_NEEDS_PROJECT_GENERATION=false
  TRINKET_NEEDS_STYLE=false
  TRINKET_NEEDS_APP_BUILD=false
  TRINKET_NEEDS_SMOKE=false
  TRINKET_NEEDS_SCRIPT_TESTS=false
  TRINKET_NEEDS_DOCS=false
  TRINKET_APP_COMPILE_SKIPPED_NO_XCODE=false
  TRINKET_SMOKE_TARGET_UNRESOLVED=false
}

# Deterministic smoke-owner mapping: which feature/UI path owns a targeted
# smoke canary. No heuristics, no demotions — a path either has an owner or it
# does not (in which case the app-compile gap-fill covers the diff).
# Class names come from Scripts/lib/smoke-classes.sh.
trinket_add_smoke_target_for_path() {
  local path="$1"

  case "$path" in
    Trinket/Features/Monetization/*)
      trinket_add_smoke_target "$TRINKET_SMOKE_CLASS_MONETIZATION"
      ;;
    Packages/TrinketBattleFeature/Sources/*|TrinketUITests/Battle/*)
      trinket_add_smoke_target "$TRINKET_SMOKE_CLASS_BATTLE"
      ;;
    Trinket/Features/Collection/*|Trinket/Features/Homestead/*|Trinket/Features/Options/*|TrinketUITests/Collection/*|TrinketUITests/Support/*)
      trinket_add_smoke_target "$TRINKET_SMOKE_CLASS_SHELL"
      ;;
    Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/AccessibilityID.swift|Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift|Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtwork.swift)
      trinket_add_smoke_target "$TRINKET_SMOKE_CLASS_SHELL"
      ;;
    Trinket/Features/Play/Shop/*)
      trinket_add_smoke_target "$TRINKET_SMOKE_CLASS_SHOP"
      ;;
    Trinket/Features/Onboarding/*)
      trinket_add_smoke_target "$TRINKET_SMOKE_CLASS_ONBOARDING"
      ;;
    Trinket/Features/Play/*|TrinketUITests/Play/*)
      trinket_add_smoke_target "$TRINKET_SMOKE_CLASS_SHELL"
      ;;
    TrinketUITests/Smoke/*.swift)
      local target="${path##*/}"
      trinket_add_smoke_target "${target%.swift}"
      if [[ "$path" == "TrinketUITests/Smoke/SmokeShellTests.swift" ]]; then
        trinket_add_smoke_target "$TRINKET_SMOKE_CLASS_ONBOARDING"
      fi
      ;;
    *)
      TRINKET_SMOKE_TARGET_UNRESOLVED=true
      ;;
  esac
}

trinket_path_is_new() {
  local path="$1"
  ! git ls-files --error-unmatch -- "$path" >/dev/null 2>&1
}

trinket_path_has_diff_pattern() {
  local path="$1"
  local pattern="$2"
  local diff_text=""
  if trinket_path_is_new "$path"; then
    [[ -f "$path" ]] && diff_text="$(sed -n '1,240p' "$path")"
  else
    diff_text="$(git diff --no-ext-diff --unified=0 -- "$path" || true)"
  fi
  printf '%s\n' "$diff_text" | grep -Eq "$pattern"
}

trinket_path_needs_doc_budget() {
  trinket_path_has_diff_pattern "$1" '//.*(swiftlint:|swiftformat:|[A-Za-z]+Check:[[:space:]]*allow|Concurrency-Safety:)'
}

trinket_path_needs_architect() {
  local path="$1"
  local pattern='(public[[:space:]]+(actor|class|enum|struct|protocol|typealias)|(^|[[:space:]])protocol[[:space:]]|@Model|[A-Za-z0-9_]+Schema|@attached)'
  local changed_pattern='^\+[^+].*'
  # A new implementation/helper file is not automatically an API-boundary
  # change. Route architecture review only when the diff declares a public or
  # schema/boundary symbol; this avoids an architect/doc-budget loop for tests.
  if trinket_path_is_new "$path"; then
    trinket_path_has_diff_pattern "$path" "$pattern"
  else
    trinket_path_has_diff_pattern "$path" "$changed_pattern$pattern"
  fi
}

trinket_path_is_visual_ui() {
  case "$1" in
    Trinket/Features/*|\
    Packages/TrinketBattleFeature/Sources/*/Features/*|Packages/TrinketBattleFeature/Sources/*/Views/*|\
    Packages/TrinketFeatureSupport/Sources/*/Features/*|Packages/TrinketFeatureSupport/Sources/*/FeatureAdapters/*|\
    Packages/TrinketFeatureSupport/Sources/*/Shared/Cards/*|Packages/TrinketFeatureSupport/Sources/*/Shared/Detail/*|\
    Packages/TrinketFeatureSupport/Sources/*/Shared/Forms/*|\
    Packages/TrinketFeatureSupport/Sources/*/Shared/Encounters/*|Packages/TrinketFeatureSupport/Sources/*/Shared/Rewards/*|\
    Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtwork*.swift)
      return 0
      ;;
    *) return 1 ;;
  esac
}

trinket_add_presentation_sections() {
  local section
  for section in display-lifetime display-work-lifecycle "$@"; do
    trinket_add_context_card "Docs/AgentContext/battle-presentation.md#$section"
  done
}

trinket_add_runtime_contracts_for_path() {
  trinket_add_route_card Docs/AgentContext/battle.md
  trinket_add_context_card Docs/AgentContext/battle-runtime.md
  case "$1" in
    *.md) ;;
    */PlaySession+BattleLaunch.swift|*/PlaySession+BattleCompletion.swift|*/PlayBattleLaunch+Configuration.swift|\
    */BattleSession+Progression.swift)
      trinket_add_context_card Docs/AgentContext/battle-launch.md ;;
    */Features/Feedback/*|*/State/Feedback/*)
      trinket_add_presentation_sections floating-combat-feedback ;;
    */Features/BattleAbilityCardView.swift|*/Features/BattleHandView.swift|*/Features/BattleFieldLane+CardPlay.swift)
      trinket_add_presentation_sections continuous-card-input card-visibility ;;
    */Features/Battlefield/*|*/Features/Effects/*)
      trinket_add_presentation_sections attack-and-impact-presentation card-visibility ;;
    */Features/BattleCombatantProjectionPane.swift|*/Features/BattleLogSheet.swift|*/Features/BattleAutoToggle.swift|\
    */Features/Layout/*|\
    */State/BattleCard*.swift|\
    */State/BattlePresentationState.swift|*/State/BattleCommandState.swift|\
    */State/BattleMotion.swift|*/State/BattleSpectacle*.swift|*/State/BattleSession+CardCues.swift|\
    */State/BattleSession+Transitions.swift)
      trinket_add_context_card Docs/AgentContext/battle-presentation.md ;;
    *)
      trinket_add_context_card Docs/AgentContext/battle-launch.md
      trinket_add_context_card Docs/AgentContext/battle-presentation.md ;;
  esac
}

trinket_add_battle_subcard_for_path() {
  case "$1" in
    Trinket/App/TrinketApp.swift)
      trinket_add_runtime_contracts_for_path "$1" ;;
    Packages/BattleEngine/Sources/BattleEngine/BattleRuntime.swift|Packages/BattleEngine/Sources/BattleEngine/BattleRuntimeDependencies.swift)
      trinket_add_runtime_contracts_for_path "$1" ;;
    Packages/BattleEngine/*)
      trinket_add_route_card Docs/AgentContext/battle.md
      trinket_add_context_card Docs/AgentContext/battle-engine.md
      case "$1" in
        */Sources/BattleBalanceTools/*|*/Sources/BalanceSweepCLI/*|*/Tests/BattleBalanceToolsTests/*)
          trinket_add_context_card Docs/AgentContext/battle-balance.md ;;
        */Triggers/CombatTriggerEngine+Damage.swift|*/Triggers/CombatTriggerEngine+BlockAndDefense.swift|*/Triggers/CombatTriggerEngine+Dodge.swift|*/Turns/BattleTurnEngine+Resolution.swift|\
        */Damage/*|*/EffectHandlers/*|*DoT*|*EffectTurnEngine*|*DamagePipeline*)
          trinket_add_context_card Docs/AgentContext/battle-damage.md ;;
        *Healing*|*Leech*)
          trinket_add_context_card Docs/AgentContext/battle-healing.md ;;
        */Cards/*|*BattleHand*|*CombatDeck*|*Mana*|*CardPlay*|*CombatResolution*|*BattleActionContext*)
          trinket_add_context_card Docs/AgentContext/battle-actions.md ;;
        *.md) ;;
        *)
          trinket_add_context_card Docs/AgentContext/battle-damage.md
          trinket_add_context_card Docs/AgentContext/battle-actions.md
          trinket_add_context_card Docs/AgentContext/battle-healing.md ;;
      esac
      ;;
    Packages/TrinketAppState/*)
      case "$1" in
        */Audio/*) ;;
        *Battle*|*/Encounter*|*/Play/*|*/State/AppState.swift|*/State/PlaySession.swift)
          trinket_add_runtime_contracts_for_path "$1"
          ;;
      esac
      ;;
    Packages/TrinketBattleFeature/*)
      trinket_add_runtime_contracts_for_path "$1"
      ;;
    *)
      ;;
  esac
}

trinket_add_persistence_contracts_for_path() {
  case "$1" in
    Packages/TrinketPersistence/*)
      trinket_add_context_card Docs/AgentContext/persistence.md
      case "$1" in
        */Sources/TrinketPersistence/Progression/*|*/Sources/TrinketPersistence/Encounters/*|\
        */Sources/TrinketPersistence/PlayerSaveStore+Homestead.swift)
          trinket_add_context_card Docs/AgentContext/persistence-progression.md ;;
        */PlayerSaveGraph/*|*/ModelContainerBootstrap.swift|*/PlayerSaveSanitizer.swift|*/PlayerSaveStoreConfiguration.swift)
          trinket_add_context_card Docs/AgentContext/persistence-storage.md ;;
        *.md) ;;
        *)
          trinket_add_context_card Docs/AgentContext/persistence-storage.md
          trinket_add_context_card Docs/AgentContext/persistence-progression.md ;;
      esac
      ;;
  esac
}

trinket_add_knowledge_for_path() {
  local path="$1"
  case "$path" in
    *PreparedArtwork*|Trinket/App/TrinketApp.swift|*PerformanceInvestigationPlaybook.md|Scripts/check-artwork-budget.sh|Scripts/check-agent-invariants.sh|Scripts/prepare-art-assets.sh|ArtManifest/*|Raw\ Assets/*)
      trinket_add_knowledge .agents/knowledge/patterns/artwork-working-set.md
      ;;
  esac
  case "$path" in
    */Package.swift|Packages/BattleEngine/*BattleState*|Packages/TrinketPersistence/*PlayerSaveStore*|Packages/TrinketAppState/*AppState*|Packages/TrinketAppState/*PlayBattle*|Packages/BattleEngine/EffectHandlers/*|Packages/BattleEngine/*DamagePipeline*|Docs/Platform/Architecture.md)
      trinket_add_knowledge .agents/knowledge/patterns/module-dag-containment.md
      ;;
  esac
  case "$path" in
    *CloudKit*|Packages/TrinketContent/Package.swift|Packages/TrinketFeatureSupport/Package.swift|Packages/TrinketBattleFeature/*Feedback*|Packages/TrinketBattleFeature/*Spectacle*|Packages/TrinketBattleFeature/*Projection*|Packages/TrinketBattleFeature/*Ultimate*|Docs/Platform/Architecture.md)
      trinket_add_knowledge .agents/knowledge/patterns/architecture-deferred-seams.md
      ;;
  esac
}

trinket_path_matches_inputs() {
  local path="$1" input
  shift
  for input in "$@"; do
    [[ "$path" == "$input" || "$path" == "$input/"* ]] && return 0
  done
  return 1
}

# Generated/processed-output detection. The registry Scripts/config/generated-paths.tsv
# is the owner (agent-search.py reads it too); this matches its content|asset
# entries exactly or beneath, so newly registered outputs classify without a
# second hardcoded list. project| entries keep their dedicated routing below.
# Unregistered generator outputs still match the fallback globs; check-links.py
# separately skips Generated path parts for link scoping. Content cache, not
# classification state: it is intentionally not reset per run.
TRINKET_GENERATED_REGISTRY=()
trinket_load_generated_registry() {
  if [[ ${#TRINKET_GENERATED_REGISTRY[@]+x} ]] && ((${#TRINKET_GENERATED_REGISTRY[@]} > 0)); then
    return 0
  fi
  local kind entry registry="$TRINKET_CHANGE_CLASSIFICATION_DIR/config/generated-paths.tsv"
  # Sparse fixture checkouts may lack the registry; fallbacks below still apply.
  [[ -f "$registry" ]] || return 0
  while IFS='|' read -r kind entry; do
    case "$kind" in content|asset) ;; *) continue ;; esac
    TRINKET_GENERATED_REGISTRY+=("$entry")
  done < <(trinket_generated_registry_rows "$registry")
}

trinket_is_generated_output() {
  local path="$1" entry
  trinket_load_generated_registry
  for entry in ${TRINKET_GENERATED_REGISTRY[@]+"${TRINKET_GENERATED_REGISTRY[@]}"}; do
    if [[ "$path" == "$entry" || "$path" == "$entry"/* ]]; then
      return 0
    fi
  done
  case "$path" in
    */Generated/*|*.generated.*|Trinket/Assets.xcassets/*|Trinket/Media/*) return 0 ;;
  esac
  return 1
}

trinket_add_package_boundary_warnings_for_path() {
  case "$1" in
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

trinket_classify_path() {
  local path="$1"

  # Documentation beneath script/manifest roots is still documentation.
  if [[ "$path" == *.md ]]; then
    TRINKET_NEEDS_DOCS=true
    TRINKET_AUTHORED_PATHS+=("$path")
    return 0
  fi

  if trinket_path_matches_inputs "$path" "${TRINKET_CONTENT_GENERATION_INPUTS[@]}"; then
    TRINKET_HAS_CONTENT=true
    TRINKET_NEEDS_CONTENT_GENERATION=true
  fi
  if trinket_path_matches_inputs "$path" "${TRINKET_ASSET_GENERATION_INPUTS[@]}"; then
    TRINKET_HAS_ASSETS=true
    TRINKET_NEEDS_ASSET_GENERATION=true
  fi

  if trinket_is_project_generation_input "$path"; then
    TRINKET_HAS_PROJECT=true
    TRINKET_NEEDS_PROJECT_GENERATION=true
  fi

  case "$path" in
    .swiftlint.yml|.swiftformat|Scripts/tool-versions.env|Scripts/format-dirs.env|Scripts/build-inputs.env)
      TRINKET_NEEDS_STYLE=true
      TRINKET_AUTHORED_PATHS+=("$path")
      return 0
      ;;
  esac

  # Generated/processed outputs route to regeneration, never to authored checks.
  # Boundary warnings still apply, so they live in one shared helper below.
  if trinket_is_generated_output "$path"; then
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
    trinket_add_package_boundary_warnings_for_path "$path"
    return 0
  fi

  case "$path" in
    Packages/TrinketContent/Sources/TrinketContent/Abilities/*.swift)
      TRINKET_HAS_CONTENT=true
      TRINKET_NEEDS_CONTENT_GENERATION=true
      TRINKET_NEEDS_STYLE=true
      trinket_add_package TrinketContent
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    project.yml)
      TRINKET_HAS_PROJECT=true
      TRINKET_NEEDS_PROJECT_GENERATION=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Packages/TrinketContent/Sources/TrinketContentTestSupport/*)
      TRINKET_NEEDS_STYLE=true
      trinket_add_package TrinketContent
      trinket_route_shared_fixture_verification
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Packages/TrinketContent/*.swift)
      TRINKET_NEEDS_STYLE=true
      trinket_route_package_verification TrinketContent
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Packages/*/*.swift)
      if trinket_classify_package_swift_path "$path"; then
        package="${path#Packages/}"
        package="${package%%/*}"
        trinket_route_package_verification "$package"
      else
        TRINKET_NEEDS_STYLE=true
        TRINKET_AUTHORED_PATHS+=("$path")
      fi
      ;;
    Trinket/App/*)
      TRINKET_NEEDS_STYLE=true
      TRINKET_NEEDS_APP_BUILD=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Scripts/*|.github/*|.githooks/*)
      TRINKET_NEEDS_SCRIPT_TESTS=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    # Non-Markdown files under Docs/ (all *.md returns early above).
    Docs/*)
      TRINKET_NEEDS_DOCS=true
      TRINKET_AUTHORED_PATHS+=("$path")
      ;;
    Trinket/Features/*|TrinketUITests/*)
      TRINKET_NEEDS_STYLE=true
      TRINKET_NEEDS_SMOKE=true
      TRINKET_HAS_FEATURE=true
      TRINKET_AUTHORED_PATHS+=("$path")
      trinket_add_smoke_target_for_path "$path"
      ;;
    *.swift)
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

  trinket_add_package_boundary_warnings_for_path "$path"
}

trinket_add_content_sections_for_path() {
  case "$1" in
    Packages/TrinketContent/Sources/TrinketContent/Abilities/*|Scripts/internal/content/abilities.py)
      trinket_add_context_card Docs/AgentContext/content-and-manifests.md#abilities ;;
    ContentManifest/*)
      trinket_add_context_card Docs/AgentContext/content-and-manifests.md#manifests ;;
    Scripts/internal/content/trigger_families/*|Scripts/internal/content/modifiers.json|Scripts/internal/content/modifier_schema.py|Scripts/internal/content/content_codegen_triggers.py|Scripts/internal/content/content_codegen_modifiers.py|Scripts/internal/content/affix_rolling.py)
      trinket_add_context_card Docs/AgentContext/content-and-manifests.md#trigger-schemas ;;
    ArtManifest/*|MusicManifest/*|SoundManifest/*|CinematicManifest/*|Raw\ Assets/*|Trinket/Assets.xcassets/*|Trinket/Media/*|Scripts/prepare-*-assets.sh|Scripts/prepare-app-icon.sh|Scripts/lib/media-assets.sh)
      trinket_add_context_card Docs/AgentContext/content-and-manifests.md#media-assets ;;
  esac
  case "$1" in
    Scripts/content_codegen.py|Scripts/internal/content/*|Scripts/generate.sh|Scripts/assert-generated-output.sh|Scripts/config/generated-paths.tsv|Packages/TrinketContent/Package.swift)
      trinket_add_context_card Docs/AgentContext/content-and-manifests.md#generation-tooling ;;
  esac
}

trinket_classify_paths() {
  trinket_reset_classification
  local path
  if [[ ${#TRINKET_CHANGED_PATHS[@]+x} ]] && (( ${#TRINKET_CHANGED_PATHS[@]} > 0 )); then
    for path in ${TRINKET_CHANGED_PATHS[@]+"${TRINKET_CHANGED_PATHS[@]}"}; do
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
    trinket_add_context_card Docs/AgentContext/content-and-manifests.md#shared-safeguards
    for path in ${TRINKET_CHANGED_PATHS[@]+"${TRINKET_CHANGED_PATHS[@]}"}; do
      trinket_add_content_sections_for_path "$path"
    done
  fi
  if [[ ${#TRINKET_PACKAGES[@]+x} ]] && (( ${#TRINKET_PACKAGES[@]} > 0 )); then
    for package in ${TRINKET_PACKAGES[@]+"${TRINKET_PACKAGES[@]}"}; do
      case "$package" in
        TrinketPersistence) trinket_add_context_card Docs/AgentContext/persistence.md ;;
        TrinketFeatureSupport) ;;
        TrinketDesignSystem) ;;
      esac
    done
  fi
  if [[ "$TRINKET_HAS_AUDIO" == true ]]; then
    trinket_add_context_card Docs/AgentContext/audio.md
  fi
  for path in ${TRINKET_CHANGED_PATHS[@]+"${TRINKET_CHANGED_PATHS[@]}"}; do
    case "$path" in
      Scripts/balance-sweep.sh|Packages/BattleEngine/*Balance*)
        trinket_add_context_card Docs/AgentContext/battle-balance.md
        break
        ;;
    esac
  done
  if [[ "$TRINKET_HAS_PROJECT" == true ]]; then
    trinket_add_context_card Docs/AgentContext/content-and-manifests.md#shared-safeguards
    trinket_add_context_card Docs/AgentContext/content-and-manifests.md#project-generation
  fi

  if [[ ${#TRINKET_CHANGED_PATHS[@]+x} ]] && (( ${#TRINKET_CHANGED_PATHS[@]} > 0 )); then
    for path in ${TRINKET_CHANGED_PATHS[@]+"${TRINKET_CHANGED_PATHS[@]}"}; do
      if [[ "$path" == *.swift ]]; then
        if trinket_path_needs_doc_budget "$path"; then
          trinket_add_skill .agents/skills/doc-budget/SKILL.md
        fi
        if trinket_path_needs_architect "$path"; then
          trinket_add_skill .agents/skills/architect/SKILL.md
          trinket_add_knowledge .agents/knowledge/patterns/module-dag-containment.md
        fi
      fi
      if trinket_path_is_visual_ui "$path"; then
        TRINKET_HAS_VISUAL_UI=true
      fi
      trinket_add_battle_subcard_for_path "$path"
      trinket_add_persistence_contracts_for_path "$path"
      if [[ "$path" == ContentManifest/talents.tsv ]]; then
        trinket_add_context_card Docs/AgentContext/battle-talents.md
      fi
      case "$path" in
        Trinket/App/*|*PreparedArtwork*|*ArtworkViewportPrewarm*|Trinket/Features/Collection/*|*LaunchWarmup*|*HiddenTabPrewarm*)
          trinket_add_context_card Docs/AgentContext/ui-performance.md
          ;;
      esac
      trinket_add_knowledge_for_path "$path"
      trinket_add_agent_guides_for_path "$path"
    done
  fi

  if [[ "$TRINKET_HAS_VISUAL_UI" == true ]]; then
    trinket_add_skill .agents/skills/apple-design/SKILL.md
    trinket_add_context_card Docs/AgentContext/swiftui-features.md
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
