#!/usr/bin/env python3
"""Select audited leaf-script regression families; unknown/shared inputs run all."""

from __future__ import annotations

import argparse
from pathlib import Path

from internal.cli import ROOT

# Keep each leaf with its consumers' regressions. Infrastructure, runners,
# fixtures, and this selector intentionally have no narrow route.
#
# INTENTIONALLY_UNMAPPED names leaves that must keep the safe full-suite
# fallback (with the reason); test_script_selection.py enforces that every
# other Scripts/ leaf is routed below.
INTENTIONALLY_UNMAPPED = {
    "Scripts/internal/cli.py": "shared by six families; any narrow route would under-test consumers",
    "Scripts/test-scripts.sh": "the runner itself; self-hosted, always full suite",
}
FAMILIES = (
    (
        {"Scripts/agent-search.py"},
        {"test_agent_search"},
    ),
    (
        {"Scripts/check-links.py", "Scripts/check-docs.py", "Scripts/check-plans.py",
         "Scripts/check-testplan-sync.py", "Scripts/agent-read.py", "Scripts/internal/markdown.py",
         "Scripts/config/smoke-classes.txt", "Scripts/new-plan.sh"},
        {"test_documentation"},
    ),
    (
        {"Scripts/aggregate-performance-results.py", "Scripts/compare-performance.py",
         "Scripts/collect-performance-results.py", "Scripts/internal/performance/performance_model.py",
         "Scripts/performance_environment.py", "Scripts/performance-scenarios.py",
         "Scripts/performance.sh"},
        {"test_aggregate_performance", "test_compare_performance", "test_performance_scenarios", "test_exec_wrappers"},
    ),
    (
        {"Scripts/release-notes-user.py"},
        {"test_release_notes_user"},
    ),
    (
        {"Scripts/agent-context.sh", "Scripts/change-classification.sh",
         "Scripts/lib/classification-plan.sh", "Scripts/lib/smoke-classes.sh",
         "Scripts/internal/agent_status.py"},
        {"test_agent_context"},
    ),
    (
        {"Scripts/build.sh", "Scripts/build-for-testing.sh", "Scripts/build-freshness.sh",
         "Scripts/check-build-cache-paths.sh", "Scripts/test.sh", "Scripts/test-package.sh",
         "Scripts/format.sh", "Scripts/lint.sh", "Scripts/lint-analyze.sh",
         "Scripts/lib/app-build.sh", "Scripts/lib/args.sh", "Scripts/lib/derived-data.sh",
         "Scripts/lib/test-helpers.sh", "Scripts/lib/test-style.sh",
         "Scripts/prune-derived-data-cache.sh", "Scripts/stage-ci-test-artifact.sh"},
        {"test_build_artifacts", "test_build_process", "test_ci_verification_scripts", "test_exec_wrappers",
         "test-lib-args.sh"},
    ),
    (
        {"Scripts/handoff.sh", "Scripts/ci-gate.sh",
         "Scripts/lib/args.sh", "Scripts/lib/cheap-slices.sh", "Scripts/config/cheap-slices.txt"},
        {"test_ci_verification_scripts", "test_documentation", "test_exec_wrappers", "test-lib-args.sh"},
    ),
    (
        {"Scripts/script_test_selection.py"},
        {"test_script_selection"},
    ),
    (
        {"Scripts/content_codegen.py", "Scripts/internal/content/content_codegen_modifiers.py",
         "Scripts/internal/content/content_codegen_triggers.py",
         "Scripts/internal/content/trigger_family_schema.json",
         "Scripts/check-ui-style.py", "Scripts/check-accessibility-ids.py",
         "Scripts/check-agent-invariants.sh", "Scripts/check-exclusivity-footguns.sh",
         "Scripts/check-module-boundaries.sh", "Scripts/check-artwork-budget.sh",
         "Scripts/check-api-bans.sh", "Scripts/release-notes.sh",
         "Scripts/config/system-colors.txt", "Scripts/config/uitest-system-query-allowlist.txt",
         "Scripts/lib/rg-check.sh", "Scripts/internal/swift_policy.py"},
        {"test_content_and_policy_scripts", "test_swift_style_policy", "test_exec_wrappers"},
    ),
    (
        {"Scripts/check-unused-assets.py"},
        {"test_check_unused_assets"},
    ),
    (
        {"Scripts/ci-path-filter.py"},
        {"test_ci_path_filter"},
    ),
    (
        {"Scripts/ci-diagnostics.py", "Scripts/ci-diagnostics.sh",
         "Scripts/failure_diagnostics.py", "Scripts/diagnostic_maintenance.py",
         "Scripts/script_diagnostics.py",
         "Scripts/internal/diagnostics/diagnostic_limits.py",
         "Scripts/internal/diagnostics/diagnostic_model.py",
         "Scripts/internal/diagnostics/diagnostic_rendering.py",
         "Scripts/internal/diagnostics/failure_diagnostics_parsers.py",
         "Scripts/internal/diagnostics/xcresult_diagnostics.py",
         "Scripts/config/diagnostic-limits.env"},
        {"test_failure_diagnostics", "test_test_timing", "test_verification_improvements", "test_exec_wrappers"},
    ),
    (
        {"Scripts/test-timing.py"},
        {"test_test_timing", "test_ci_verification_scripts"},
    ),
    (
        {"Scripts/prepare-art-assets.sh", "Scripts/prepare-audio-assets.sh",
         "Scripts/prepare-cinematic-assets.sh", "Scripts/prepare-assets.sh",
         "Scripts/prepare-app-icon.sh", "Scripts/lib/media-assets.sh",
         "Scripts/ci-assets-gate.sh", "Scripts/report-art-memory.sh"},
        {"test_media_asset_scripts", "test_ci_verification_scripts", "test-asset-hash-sort-locale.sh"},
    ),
    (
        {"Scripts/generate.sh", "Scripts/agent-push-gate.sh",
         "Scripts/assert-generated-output.sh", "Scripts/change-budget.sh",
         "Scripts/apply-scheme-storekit.py", "Scripts/check-staged-project.sh",
         "Scripts/ensure-ci-tools.sh", "Scripts/ensure-git-cliff.sh", "Scripts/update-tools.sh",
         "Scripts/lib/project-generation.sh", "Scripts/lib/tools.sh",
         "Scripts/lib/tool-install.sh", "Scripts/lib/ci-tools.d/xcodegen.sh",
         "Scripts/lib/ci-tools.d/ripgrep.sh",
         "Scripts/build-inputs.env", "Scripts/format-dirs.env", "Scripts/tool-versions.env",
         "Scripts/config/generated-paths.tsv", "Scripts/config/smoke-classes.txt"},
        {"test_project_generation", "test_build_process", "test_ci_verification_scripts"},
    ),
    (
        {"Scripts/run-env.sh", "Scripts/ensure-simulator.sh", "Scripts/simctl_json.py",
         "Scripts/lib/simctl.sh", "Scripts/lib/slots.sh", "Scripts/lib/lock.sh",
         "Scripts/config/simulator-names.env"},
        {"test_exec_wrappers", "test-run-env.sh"},
    ),
    (
        {"Scripts/xcode-runner.sh", "Scripts/lib/xcode-manifest.sh",
         "Scripts/lib/xcode-watchdog.sh", "Scripts/lib/xcodebuild-infra.sh",
         "Scripts/lib/infrastructure-patterns.sh",
         "Scripts/config/infrastructure-patterns.env"},
        {"test_exec_wrappers", "test-xcode-runner.sh"},
    ),
    (
        {"Scripts/release.sh", "Scripts/test-deploy.sh",
         "Scripts/promote.sh", "Scripts/lib/promote.sh",
         "Scripts/install-device.sh", "Scripts/run-simulator.sh",
         "Scripts/validate-commit-msg.sh", "Scripts/record-time-profiler.sh"},
        {"test_release_notes_user", "test_ci_verification_scripts"},
    ),
    (
        {"Scripts/balance-sweep.sh"},
        {"test_balance_report_retention"},
    ),
    (
        {"Scripts/agent-worktree.mjs", "Scripts/setup-git-safety.mjs",
         "Scripts/git-safety-guard.mjs", "Scripts/agent-watch-ci.sh",
         "Scripts/ci-infra-rerun.sh", "Scripts/config/destructive-git-commands.txt",
         "Scripts/bin/git"},
        {"test_exec_wrappers"},
    ),
)


def _module_path(module: str) -> str:
    if module.endswith(".sh"):
        return f"Scripts/Tests/{module}"
    return f"Scripts/Tests/{module}.py"


def select_tests(paths: list[str], root: Path = ROOT) -> list[str]:
    available = sorted(
        path.relative_to(root).as_posix()
        for path in (root / "Scripts/Tests").iterdir()
        if (path.name.startswith("test") and path.suffix == ".py")
        or (path.name.startswith("test-") and path.suffix == ".sh")
    )
    if not paths:
        return available
    available_set = set(available)
    selected: set[str] = set()
    for raw in paths:
        path = Path(raw).as_posix()
        if Path(path).is_absolute() or ".." in Path(path).parts:
            raise ValueError("--paths requires repository-relative files")
        if (root / path).is_dir():
            raise ValueError("--paths requires individual files, not directories")
        if path.endswith(".md"):
            continue
        # Editing a regression module runs just itself.
        if path in available_set:
            selected.add(path)
            continue
        families = [modules for owners, modules in FAMILIES if path in owners]
        if not families:
            return available
        for modules in families:
            selected.update(_module_path(module) for module in modules)
    missing = selected - available_set
    if missing:
        raise ValueError(f"selected regression modules are missing: {', '.join(sorted(missing))}")
    return sorted(selected)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--paths", nargs="+", default=[])
    args = parser.parse_args()
    try:
        print("\n".join(select_tests(args.paths)))
    except ValueError as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
