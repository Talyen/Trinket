#!/usr/bin/env python3
"""Execution-free coverage for top-level wrappers lacking dedicated tests.

Covers --help/unknown-arg paths for test.sh, build-for-testing.sh,
test-scripts.sh, and performance.sh without requiring Xcode or simulators.
"""

SCRIPT_INPUTS = (
    'Scripts/agent-watch-ci.sh',
    'Scripts/agent-worktree.mjs',
    'Scripts/aggregate-performance-results.py',
    'Scripts/bin/git',
    'Scripts/build-for-testing.sh',
    'Scripts/build-freshness.sh',
    'Scripts/build.sh',
    'Scripts/check-accessibility-ids.py',
    'Scripts/check-agent-invariants.sh',
    'Scripts/check-api-bans.sh',
    'Scripts/check-artwork-budget.sh',
    'Scripts/check-build-cache-paths.sh',
    'Scripts/check-exclusivity-footguns.sh',
    'Scripts/check-module-boundaries.sh',
    'Scripts/check-ui-style.py',
    'Scripts/ci-diagnostics.py',
    'Scripts/ci-diagnostics.sh',
    'Scripts/ci-gate.sh',
    'Scripts/ci-infra-rerun.sh',
    'Scripts/collect-performance-results.py',
    'Scripts/compare-performance.py',
    'Scripts/config/cheap-slices.txt',
    'Scripts/config/destructive-git-commands.txt',
    'Scripts/config/diagnostic-limits.env',
    'Scripts/config/infrastructure-patterns.env',
    'Scripts/config/simulator-names.env',
    'Scripts/config/system-colors.txt',
    'Scripts/config/uitest-system-query-allowlist.txt',
    'Scripts/diagnostic_maintenance.py',
    'Scripts/ensure-simulator.sh',
    'Scripts/failure_diagnostics.py',
    'Scripts/format.sh',
    'Scripts/git-safety-guard.mjs',
    'Scripts/handoff.sh',
    'Scripts/internal/diagnostics/diagnostic_limits.py',
    'Scripts/internal/diagnostics/diagnostic_model.py',
    'Scripts/internal/diagnostics/diagnostic_rendering.py',
    'Scripts/internal/diagnostics/failure_diagnostics_parsers.py',
    'Scripts/internal/diagnostics/xcresult_diagnostics.py',
    'Scripts/internal/performance/performance_model.py',
    'Scripts/internal/swift_policy.py',
    'Scripts/lib/app-build.sh',
    'Scripts/lib/args.sh',
    'Scripts/lib/cheap-slices.sh',
    'Scripts/lib/derived-data.sh',
    'Scripts/lib/gate.sh',
    'Scripts/lib/infrastructure-patterns.sh',
    'Scripts/lib/lock.sh',
    'Scripts/lib/rg-check.sh',
    'Scripts/lib/simctl.sh',
    'Scripts/lib/slots.sh',
    'Scripts/lib/tempdir.sh',
    'Scripts/lib/test-helpers.sh',
    'Scripts/lib/test-style.sh',
    'Scripts/lib/xcode-manifest.sh',
    'Scripts/lib/xcode-watchdog.sh',
    'Scripts/lib/xcodebuild-infra.sh',
    'Scripts/lint-analyze.sh',
    'Scripts/lint.sh',
    'Scripts/package-diagnostics.py',
    'Scripts/performance-scenarios.py',
    'Scripts/performance.sh',
    'Scripts/performance_environment.py',
    'Scripts/playthrough-sweep.sh',
    'Scripts/playthrough_sweep.py',
    'Scripts/prune-derived-data-cache.sh',
    'Scripts/release-notes.sh',
    'Scripts/run-env.sh',
    'Scripts/script_diagnostics.py',
    'Scripts/setup-git-safety.mjs',
    'Scripts/simctl_json.py',
    'Scripts/stage-ci-test-artifact.sh',
    'Scripts/restore-ci-test-products.sh',
    'Scripts/test-package.sh',
    'Scripts/test.sh',
    'Scripts/xcode-runner.sh',
)


import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def run_script(name: str, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(ROOT / "Scripts" / name), *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


class ExecWrapperTests(unittest.TestCase):


    # Every directly-invokable entry point documents --help; sourced libs,
    # hooks, and CI-internal shims stay out and are pinned below so a new
    # script must pick a side.
    HELP_SCRIPTS = (
        "agent-context.sh",
        "agent-push-gate.sh",
        "agent-watch-ci.sh",
        "assert-generated-output.sh",
        "balance-sweep.sh",
        "build-for-testing.sh",
        "build.sh",
        "change-budget.sh",
        "check-agent-invariants.sh",
        "check-api-bans.sh",
        "check-artwork-budget.sh",
        "check-build-cache-paths.sh",
        "check-exclusivity-footguns.sh",
        "check-module-boundaries.sh",
        "ci-assets-gate.sh",
        "ci-diagnostics.sh",
        "ci-gate.sh",
        "ci-infra-rerun.sh",
        "ensure-ci-tools.sh",
        "format.sh",
        "generate.sh",
        "handoff.sh",
        "install-device.sh",
        "lint-analyze.sh",
        "lint.sh",
        "new-plan.sh",
        "performance.sh",
        "playthrough-sweep.sh",
        "prepare-assets.sh",
        "prepare-audio-assets.sh",
        "promote.sh",
        "prune-derived-data-cache.sh",
        "record-time-profiler.sh",
        "release-notes.sh",
        "release.sh",
        "report-art-memory.sh",
        "run-simulator.sh",
        "setup-testflight.sh",
        "test-deploy.sh",
        "test-package.sh",
        "test-scripts.sh",
        "test.sh",
        "testflight.sh",
        "update-tools.sh",
    )
    NO_HELP_SCRIPTS = (
        # Sourced by entry points, never executed directly.
        "build-freshness.sh",
        "change-classification.sh",
        "run-env.sh",
        "xcode-runner.sh",
        # Invoked by hooks/CI/generate with fixed args.
        "check-staged-project.sh",
        "ensure-git-cliff.sh",
        "ensure-simulator.sh",
        "prepare-app-icon.sh",
        "prepare-art-assets.sh",
        "prepare-cinematic-assets.sh",
        "stage-ci-test-artifact.sh",
        "restore-ci-test-products.sh",
        "validate-commit-msg.sh",
    )

    def test_help_exits_zero(self) -> None:
        for script in self.HELP_SCRIPTS:
            with self.subTest(script=script):
                result = run_script(script, "--help")
                self.assertEqual(result.returncode, 0, script + result.stderr)
                self.assertIn("Usage:", result.stdout, script)

    def test_help_surface_is_complete(self) -> None:
        actual = sorted(path.name for path in (ROOT / "Scripts").glob("*.sh"))
        self.assertEqual(sorted(self.HELP_SCRIPTS + self.NO_HELP_SCRIPTS), actual)

    def test_unknown_arg_fails(self) -> None:
        for script in ("build-for-testing.sh", "test-scripts.sh"):
            result = run_script(script, "--definitely-not-a-flag")
            self.assertNotEqual(result.returncode, 0, script)
            self.assertIn("Unknown argument", result.stderr, script)

    def test_test_sh_unknown_argument_fails(self) -> None:
        result = run_script("test.sh", "--definitely-not-a-flag")
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertIn("Unknown argument", result.stderr)


if __name__ == "__main__":
    unittest.main()
