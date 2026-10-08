#!/usr/bin/env python3

from __future__ import annotations

SCRIPT_INPUTS = (
    '.github/actions/setup-trinket/action.yml',
    'Scripts/phase-timing.py',
    'Scripts/agent-push-gate.sh',
    'Scripts/apply-scheme-storekit.py',
    'Scripts/assert-generated-output.sh',
    'Scripts/build-for-testing.sh',
    'Scripts/build-freshness.sh',
    'Scripts/build-inputs.env',
    'Scripts/build.sh',
    'Scripts/change-budget.sh',
    'Scripts/check-build-cache-paths.sh',
    'Scripts/check-staged-project.sh',
    'Scripts/ci-assets-gate.sh',
    'Scripts/config/generated-paths.tsv',
    'Scripts/config/infrastructure-patterns.env',
    'Scripts/config/simulator-names.env',
    'Scripts/config/ui-tests.tsv',
    'Scripts/ensure-ci-tools.sh',
    'Scripts/ensure-git-cliff.sh',
    'Scripts/ensure-simulator.sh',
    'Scripts/format-dirs.env',
    'Scripts/format.sh',
    'Scripts/generate.sh',
    'Scripts/install-device.sh',
    'Scripts/lib/app-build.sh',
    'Scripts/lib/args.sh',
    'Scripts/lib/ci-tools.d/ripgrep.sh',
    'Scripts/lib/ci-tools.d/xcodegen.sh',
    'Scripts/lib/derived-data.sh',
    'Scripts/lib/generated-paths.sh',
    'Scripts/lib/infrastructure-patterns.sh',
    'Scripts/lib/lock.sh',
    'Scripts/lib/media-assets.sh',
    'Scripts/lib/project-generation.sh',
    'Scripts/lib/promote.sh',
    'Scripts/lib/simctl.sh',
    'Scripts/lib/slots.sh',
    'Scripts/lib/tempdir.sh',
    'Scripts/lib/test-helpers.sh',
    'Scripts/lib/test-style.sh',
    'Scripts/lib/tool-install.sh',
    'Scripts/lib/tools.sh',
    'Scripts/lib/xcode-manifest.sh',
    'Scripts/lib/xcode-watchdog.sh',
    'Scripts/lib/xcodebuild-infra.sh',
    'Scripts/lint-analyze.sh',
    'Scripts/lint.sh',
    'Scripts/prepare-app-icon.sh',
    'Scripts/prepare-art-assets.sh',
    'Scripts/prepare-assets.sh',
    'Scripts/prepare-audio-assets.sh',
    'Scripts/promote.sh',
    'Scripts/prune-derived-data-cache.sh',
    'Scripts/record-time-profiler.sh',
    'Scripts/release.sh',
    'Scripts/report-art-memory.sh',
    'Scripts/run-env.sh',
    'Scripts/run-simulator.sh',
    'Scripts/simctl_json.py',
    'Scripts/stage-ci-test-artifact.sh',
    'Scripts/test-deploy.sh',
    'Scripts/test-package.sh',
    'Scripts/test-timing.py',
    'Scripts/test.sh',
    'Scripts/tool-versions.env',
    'Scripts/update-tools.sh',
    'Scripts/validate-commit-msg.sh',
    'Scripts/xcode-runner.sh',
)


import json
import os
import subprocess
import tempfile
import time
import unittest

from script_test_support import ROOT, ScriptRegressionTestCase

import shutil
from pathlib import Path

class CIBuildScriptTests(ScriptRegressionTestCase):
    def test_successful_test_process_requires_execution_evidence(self) -> None:
        cases = (
            ('empty', 'test', '', None, 1, False),
            ('skipped', 'test', 'Executed 1 test, with 1 test skipped and 0 failures', None, 1, False),
            ('swift-skipped', 'test', '↷ Test example() skipped.\n✔ Test run with 1 test passed after 0.1 seconds.', None, 1, False),
            ('swift-empty-cases', 'test', '✔ Test example() with 0 test cases passed after 0.1 seconds.\n✔ Test run with 1 test passed after 0.1 seconds.', None, 1, False),
            ('swift-completed', 'test', '✔ Test example() passed after 0.1 seconds.\n✔ Test run with 1 test passed after 0.1 seconds.', None, 0, True),
            ('summary-zero', 'test', 'Executed 1 test, with 0 failures',
             {'result': 'Passed', 'passedTests': 0, 'failedTests': 0, 'skippedTests': 1}, 1, False),
            ('summary', 'test', '', {'result': 'Passed', 'passedTests': 1, 'failedTests': 0}, 0, True),
            ('failed-count', 'test', '', {'result': 'Passed', 'passedTests': 1, 'failedTests': 1}, 1, True),
            ('boolean-count', 'test', '', {'result': 'Passed', 'passedTests': True, 'failedTests': 0}, 1, False),
            ('log', 'test-without-building', 'Executed 2 tests, with 1 test skipped and 0 failures', None, 0, True),
            ('compile', 'build-for-testing', '', None, 0, False),
        )
        for name, action, log, summary, expected, executed in cases:
            with self.subTest(case=name), tempfile.TemporaryDirectory() as directory:
                root = self.make_repo_fixture(directory, (
                    'Scripts/xcode-runner.sh', 'Scripts/config/diagnostic-limits.env',
                    'Scripts/lib/xcode-manifest.sh', 'Scripts/lib/xcode-watchdog.sh',
                ))
                tools = root / 'bin'
                tools.mkdir()
                for filename, source in (
                    ('xcodebuild', '#!/bin/sh\nprintf "%s\\n" "$FAKE_LOG"\n'),
                    ('reporter', '#!/bin/sh\nexit 0\n'),
                ):
                    script = tools / filename
                    script.write_text(source)
                    script.chmod(0o755)
                script = '''source Scripts/xcode-runner.sh
xcode_runner_prepare unit "$PWD/results"
if [[ "$FAKE_SUMMARY" != null ]]; then
    mkdir -p "$XCODE_RUNNER_RESULT_BUNDLE_PATH"
    touch "$XCODE_RUNNER_RESULT_BUNDLE_PATH/Info.plist"
fi
xcrun() { printf '%s' "$FAKE_SUMMARY"; }
xcode_runner_run --quiet --label unit --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH" --log "$XCODE_RUNNER_LOG_PATH" --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" -- xcodebuild "$1"
'''
                result = subprocess.run(['/bin/bash', '-c', script, '_', action], cwd=root,
                    env={**self.verification_environment(), 'PATH': str(tools) + ':' + os.environ['PATH'],
                         'FAKE_LOG': log, 'FAKE_SUMMARY': json.dumps(summary),
                         'XCODE_RUNNER_REPORTER': str(tools / 'reporter'),
                         'TRINKET_XCODE_WALL_TIMEOUT_SECONDS': '0', 'TRINKET_XCODE_IDLE_TIMEOUT_SECONDS': '0'},
                    capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                manifest = json.loads(next((root / 'results').glob('*-invocation.json')).read_text())
                self.assertEqual(manifest['status'], 'passed' if expected == 0 else 'failed')
                self.assertEqual(manifest['test_execution_proven'], executed)
                self.assertEqual(manifest.get('test_summary'), summary)




    def test_build_cache_paths_reject_drifted_registry(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(
                directory,
                ("Scripts/check-build-cache-paths.sh", "Scripts/build-freshness.sh",
                 "Scripts/build-inputs.env", ".github/actions/build-cache-key/action.yml"),
            )
            action = root / ".github/actions/build-cache-key/action.yml"
            live = action.read_text(encoding="utf-8")

            def run_checker() -> subprocess.CompletedProcess[str]:
                return subprocess.run(
                    [str(root / "Scripts/check-build-cache-paths.sh")],
                    cwd=root,
                    capture_output=True,
                    text=True,
                    check=False,
                )

            lines = live.splitlines(keepends=True)
            full_index = next(i for i, line in enumerate(lines) if "full=" in line)
            self.assertIn("'Trinket/**', ", lines[full_index])
            lines[full_index] = lines[full_index].replace("'Trinket/**', ", "", 1)
            action.write_text("".join(lines), encoding="utf-8")
            result = run_checker()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("must include Trinket/**", result.stderr)

            lines = live.splitlines(keepends=True)
            nonsource_index = next(i for i, line in enumerate(lines) if "nonsource=" in line)
            self.assertNotIn("Scripts/**", lines[nonsource_index])
            lines[nonsource_index] = lines[nonsource_index].replace(
                "hashFiles(", "hashFiles('Scripts/**', ", 1
            )
            action.write_text("".join(lines), encoding="utf-8")
            result = run_checker()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("must not include Scripts/**", result.stderr)

    def test_release_compile_is_required_only_for_nightly_and_manual_runs(self):
        workflow = (ROOT / ".github/workflows/tests.yml").read_text()
        release = workflow.split("  release-device:\n", 1)[1].split("  unit:\n", 1)[0]
        self.assertIn("needs: [changes, reuse, build, unit]", release)
        self.assertIn("github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'", release)
        self.assertIn("needs.build.result == 'success' || needs.reuse.outputs.standard == 'true'", release)
        self.assertIn("timeout-minutes: 30", release)
        self.assertIn("./Scripts/build.sh --release-device --quiet", release)
        self.assertIn("SKIP_GENERATE: 1", release)
        self.assertIn("TRINKET_XCODE_WALL_TIMEOUT_SECONDS", release)
        self.assertIn("'1800'", release)
        self.assertIn("if: failure()", release)
        self.assertIn("path: .DerivedData/TestResults", release)
        aggregate = workflow.split("  ci-ok:\n", 1)[1].split("  exhaustive-ok:\n", 1)[0]
        self.assertIn("release-device", aggregate.split("if: always()", 1)[0])
        command = aggregate.split("        run: |\n", 1)[1].split("\n  #", 1)[0]
        for outcome, status in (("success", 0), ("skipped", 0), ("failure", 1), ("cancelled", 1)):
            result = subprocess.run(["bash", "-ec", command], capture_output=True,
                                    env={**os.environ, "RESULTS": f"success {outcome}"})
            self.assertEqual(result.returncode, status)

    def test_ci_transfer_validation_and_job_local_xcode_selection(self):
        setup = (ROOT / ".github/actions/setup-trinket/action.yml").read_text()
        self.assertNotIn("sudo xcode-select", setup)
        self.assertIn('python3 Scripts/setup-ci-xcode.py "${args[@]}"', setup)
        job = (ROOT / ".github/actions/test-job/action.yml").read_text()
        self.assertIn("./Scripts/restore-ci-test-products.sh", job)
        self.assertLess(job.index("./Scripts/restore-ci-test-products.sh"), job.index("- name: Run tests"))
        workflow = (ROOT / '.github/workflows/tests.yml').read_text()
        for name, following in (('exhaustive-ui', 'diff-review'),):
            with self.subTest(job=name):
                consumer = workflow.split(f'  {name}:\n', 1)[1].split(f'  {following}:\n', 1)[0]
                self.assertIn('rebuild-command: ./Scripts/build-for-testing.sh --app-only', consumer)
                self.assertRegex(consumer, r'uses: \./\.github/actions/setup-trinket\n(?:\s+if:.*\n)?\s+with:\n(?:\s+#.*\n)*\s+metal: \'true\'')

    def test_build_smoke_and_exhaustive_keep_registry_coverage(self):
        workflow = (ROOT / '.github/workflows/tests.yml').read_text()
        build = workflow.split('  build:\n', 1)[1].split('  release-device:\n', 1)[0]
        self.assertIn('python3 Scripts/check-testplan-sync.py --classes Smoke', build)
        self.assertIn('./Scripts/test.sh smoke --no-build ${{ steps.ui-matrices.outputs.smoke-targets }}', build)
        self.assertIn("upload-artifact: 'true'", build)
        self.assertNotIn('build-artifact:', build.split('- name: Run smoke', 1)[1])
        exhaustive = workflow.split('  exhaustive-ui:\n', 1)[1].split('  diff-review:\n', 1)[0]
        self.assertIn('--classes FullUI', exhaustive)
        self.assertIn('./Scripts/test.sh ui --no-build ${{ steps.ui-targets.outputs.targets }}', exhaustive)
        aggregate = workflow.split('  ci-ok:\n', 1)[1].split('  exhaustive-ok:\n', 1)[0]
        self.assertIn('build', aggregate.split('if: always()', 1)[0])

    def test_idempotence_checks_outputs_even_with_a_fresh_stamp(self) -> None:
        for initial, generator, expected in (
            ("stable", "printf stable > output", 0),
            ("damaged", "printf stable > output", 1),
            ("stable", "printf churn >> output", 1),
        ):
            with self.subTest(initial=initial, generator=generator), tempfile.TemporaryDirectory() as directory:
                root = self.make_repo_fixture(
                    directory,
                    ("Scripts/assert-generated-output.sh", "Scripts/build-freshness.sh",
                     "Scripts/build-inputs.env", "Scripts/lib/generated-paths.sh"),
                )
                (root / "Scripts/config").mkdir(parents=True)
                (root / "Trinket.xcodeproj").mkdir()
                (root / "results").mkdir()
                (root / "Scripts/config/generated-paths.tsv").write_text("content|output\n")
                (root / "Scripts/run-env.sh").write_text(
                    'trinket_run_env_init() { export RESULTS_DIR="$PWD/results"; }\n'
                )
                generate = root / "Scripts/generate.sh"
                generate.write_text('#!/bin/bash\n[[ ("$*" == "" || "$*" == "--assets") && "$TRINKET_FORCE_ABILITY_DUMP" == 1 ]] || exit 9\nprintf called >> calls\n' + generator + "\n")
                generate.chmod(0o755)
                identifier = "A" * 24
                (root / "Trinket.xcodeproj/project.pbxproj").write_text(
                    "Begin PBXNativeTarget section\n"
                    + identifier + " /* target */\nEnd PBXNativeTarget section\n"
                )
                (root / "Smoke.xctestplan").write_text(json.dumps({"identifier": identifier}))
                (root / "output").write_text(initial)
                stamp = root / "results/.last-generate.stamp"
                stamp.touch()
                os.utime(stamp, (time.time() + 60, time.time() + 60))
                result = subprocess.run(
                    ["bash", "Scripts/assert-generated-output.sh", "--idempotent"],
                    cwd=root, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                self.assertEqual((root / "calls").read_text(), "called")

    def test_generation_reuses_dirty_inputs_and_detects_edits_and_deletions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(
                directory, ("Scripts/build-freshness.sh", "Scripts/build-inputs.env"))
            prepare = root / 'Scripts/prepare-assets.sh'
            prepare.write_text('#!/bin/bash\n[[ "$*" == "--heal" ]] && exit 0\n[[ "$*" == "--check --outputs-only" ]] || exit 9\n[[ ! -f invalid-assets ]] || exit 7\nprintf checked >> asset-checks\n')
            prepare.chmod(0o755)
            generate = root / "Scripts/generate.sh"
            generate.write_text('#!/bin/bash\necho generated >> calls\n')
            generate.chmod(0o755)
            script = """
unset TRINKET_SHARED_DERIVED_DATA SKIP_GENERATE
source Scripts/build-freshness.sh
content_generation_inputs=(input); project_generation_inputs=(project); asset_generation_inputs=(asset)
touch input project asset
git() { printf ' M input\\n'; }
prepare_generated_inputs results
prepare_generated_inputs results
[[ $(wc -l < calls) -eq 1 ]]
printf changed > input
prepare_generated_inputs results
[[ $(wc -l < calls) -eq 2 ]]
rm input
prepare_generated_inputs results
[[ $(wc -l < calls) -eq 3 ]]
prepare_generated_inputs results
[[ $(wc -l < calls) -eq 3 ]]
printf changed > asset
prepare_generated_inputs results
[[ $(wc -l < calls) -eq 4 ]]
touch invalid-assets
status=0
prepare_generated_inputs results || status=$?
[[ $status -eq 7 ]]
[[ $(wc -l < calls) -eq 4 ]]
"""
            result = subprocess.run(["bash", "-eu", "-c", script], cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_generation_tracks_shared_generator_helpers(self) -> None:
        for relative, expected in (
            ("Scripts/lib/project-generation.sh", ""),
            ("Scripts/tool-versions.env", ""),
            ("Scripts/lib/ci-tools.d/xcodegen.sh", ""),
            ("Trinket.xcodeproj/project.pbxproj", ""),
            ("Scripts/internal/content/content_codegen_modifiers.py", "--skip-xcodegen"),
            ("Scripts/internal/content/content_codegen_triggers.py", "--skip-xcodegen"),
            ("Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityCatalog.swift", "--skip-xcodegen"),
            ("Packages/TrinketContent/Sources/TrinketContent/Encounters/Mystery/MysteryEventPool+Events.swift", "--skip-xcodegen"),
            ("Packages/TrinketContent/Sources/TrinketContent/Encounters/Mystery/RecruitEventPool.swift", "--skip-xcodegen"),
            ("Scripts/lib/media-assets.sh", ""),
            ("Scripts/config/full-only-art-kinds.txt", ""),
            ("Scripts/prepare-assets.sh", ""),
        ):
            with self.subTest(path=relative), tempfile.TemporaryDirectory() as directory:
                root = self.make_repo_fixture(
                    directory, ("Scripts/build-freshness.sh", "Scripts/build-inputs.env"))
                prepare = root / 'Scripts/prepare-assets.sh'
                prepare.write_text('#!/bin/bash\n[[ "$*" == "--heal" ]] && exit 0\n[[ "$*" == "--check --outputs-only" ]] || exit 9\nprintf checked >> asset-checks\n')
                prepare.chmod(0o755)
                (root / "ContentManifest").mkdir()
                (root / "ContentManifest/input.tsv").touch()
                (root / "ArtManifest").mkdir()
                (root / "ArtManifest/input.tsv").touch()
                (root / "project.yml").touch()
                (root / relative).parent.mkdir(parents=True, exist_ok=True)
                (root / relative).touch()
                generate = root / "Scripts/generate.sh"
                generate.write_text('#!/bin/bash\nprintf "%s" "$*" > calls\n')
                generate.chmod(0o755)
                (root / "results").mkdir()
                stamp = root / "results/.last-generate.stamp"
                subprocess.run(["bash", "-ec", "source Scripts/build-freshness.sh; touch_generate_stamp results"], cwd=root, check=True)
                os.utime(root / relative, (time.time() + 60, time.time() + 60))
                result = subprocess.run(
                    ["bash", "-ec", "unset TRINKET_SHARED_DERIVED_DATA SKIP_GENERATE; source Scripts/build-freshness.sh; prepare_generated_inputs results"],
                    cwd=root, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((root / "calls").read_text(), expected)

    def test_asset_dispatch_validates_before_conversion(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(
                directory, ("Scripts/prepare-assets.sh", "Scripts/lib/args.sh"))
            (root / 'Scripts/asset-library.py').write_text('import sys\nsys.exit(0)\n')
            for kind in ("art", "audio", "app-icon"):
                pipeline = root / "Scripts" / f"prepare-{kind}-assets.sh"
                if kind == "app-icon":
                    pipeline = root / "Scripts/prepare-app-icon.sh"
                pipeline.write_text('#!/bin/bash\nprintf "%s %s\\n" "$0" "$*" >> calls\n')
                pipeline.chmod(0o755)
            for arguments in (("--kind", "typo"), ("--kind", "art", "extra"), ("--kind",)):
                with self.subTest(arguments=arguments):
                    result = subprocess.run(
                        ["bash", "Scripts/prepare-assets.sh", *arguments],
                        cwd=root, capture_output=True, text=True,
                    )
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse((root / "calls").exists())
            result = subprocess.run(
                ["bash", "Scripts/prepare-assets.sh", "--kind", "sfx"],
                cwd=root, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / "calls").read_text(), "Scripts/prepare-audio-assets.sh sfx\n")

    def test_bare_full_ui_requires_explicit_opt_in(self) -> None:
        # Full exhaustive UI is CI-owned post-push; bare local runs must opt in.
        test_sh = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        self.assertIn('TRINKET_ALLOW_FULL_UI:-', test_sh)
        self.assertIn('GITHUB_ACTIONS:-}', test_sh)
        self.assertIn("Refusing a bare local full exhaustive UI run", test_sh)
        deploy = (ROOT / "Scripts" / "test-deploy.sh").read_text(encoding="utf-8")
        # Release-time deploy verification is the sanctioned bypass.
        self.assertIn("TRINKET_ALLOW_FULL_UI=1 ./Scripts/test.sh ui", deploy)

    def test_unit_dispatch_forwards_flags_and_exit_without_app_preparation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(directory, (
                "Scripts/test.sh", "Scripts/build-freshness.sh", "Scripts/build-inputs.env",
                "Scripts/lib/args.sh", "Scripts/xcode-runner.sh", "Scripts/config/diagnostic-limits.env",
                "Scripts/lib/xcode-manifest.sh", "Scripts/lib/xcode-watchdog.sh",
            ))
            scripts = root / "Scripts"
            (scripts / "run-env.sh").write_text('trinket_run_env_init() { exit 91; }\n')
            (scripts / "test-package.sh").write_text('#!/bin/bash\nprintf "%s\\n" "$@"\nexit 17\n')
            (scripts / "test-package.sh").chmod(0o755)
            for flags in (("--no-build", "--verbose"), ("--quiet",)):
                result = subprocess.run([str(scripts / "test.sh"), "unit", *flags],
                                        env={**os.environ, "GITHUB_ACTIONS": "true"}, capture_output=True, text=True)
                self.assertEqual(result.returncode, 17, result.stdout + result.stderr)
                args = result.stdout.splitlines()
                self.assertEqual(args[:len(flags)], list(flags))
                self.assertIn("BattleEngine", args)
                self.assertEqual(len(args), len(set(args)))


    def test_package_build_prepares_generated_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(directory, (
                "Scripts/test-package.sh", "Scripts/phase-timing.py", "Scripts/lib/args.sh",
                "Scripts/lib/app-build.sh", "Scripts/xcode-runner.sh", "Scripts/config/diagnostic-limits.env",
                "Scripts/lib/xcode-manifest.sh", "Scripts/lib/xcode-watchdog.sh",
            ))
            scripts = root / "Scripts"
            (scripts / "run-env.sh").write_text(
                'source Scripts/lib/args.sh\ntrinket_run_env_init() { RESULTS_DIR="$PWD/results"; }\ntrinket_track_test_guests() { :; }\n'
            )
            (scripts / "ensure-simulator.sh").write_text('trinket_sim_slot_ensure() { :; }\n')
            (scripts / "build-freshness.sh").write_text(
                'TRINKET_TEST_PACKAGES=(BattleEngine)\n'
                'prepare_generated_inputs() { echo "prepared inputs"; exit 73; }\n'
            )
            for action in (
                ["--destination", "platform=iOS Simulator,name=Fixture"],
                ["--destination", "id=fixture"],
                ["--build-for-testing"],
            ):
                with self.subTest(action=action):
                    result = subprocess.run(
                        [str(scripts / "test-package.sh"), *action, "BattleEngine"],
                        env={**os.environ, "GITHUB_ACTIONS": "true"}, capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 73, result.stdout + result.stderr)
                    self.assertIn("prepared inputs", result.stdout)



if __name__ == "__main__":
    unittest.main()
