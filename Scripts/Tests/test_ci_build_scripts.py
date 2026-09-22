#!/usr/bin/env python3

from __future__ import annotations

SCRIPT_INPUTS = (
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
    'Scripts/prepare-cinematic-assets.sh',
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
    def test_generate_pins_c_locale(self) -> None:
        text = (ROOT / "Scripts" / "generate.sh").read_text(encoding="utf-8")
        self.assertIn("export LC_ALL=C", text)
        self.assertIn("export LANG=C", text)

    def test_generate_pins_xcode_macos_sdk(self) -> None:
        text = (ROOT / "Scripts" / "generate.sh").read_text(encoding="utf-8")
        self.assertIn("ensure_xcode_macos_sdk", text)
        self.assertIn("export DEVELOPER_DIR=", text)
        self.assertIn("export SDKROOT=", text)
        self.assertIn("CommandLineTools", text)

    def test_build_inputs_include_xctestplans(self) -> None:
        text = (ROOT / "Scripts" / "build-freshness.sh").read_text(encoding="utf-8")
        owner = (ROOT / "Scripts" / "build-inputs.env").read_text(encoding="utf-8")
        for plan in (
            "Smoke.xctestplan",
            "FullUI.xctestplan",
            "BattlePerformance.xctestplan",
        ):
            self.assertIn(plan, owner)
        self.assertIn('build_input_paths=("${TRINKET_BUILD_ROOTS[@]}" "${TRINKET_PROJECT_INPUTS[@]}")', text)
        self.assertNotIn("Package.resolved", text)

    def test_build_cache_paths_aligned(self) -> None:
        result = subprocess.run(
            [str(ROOT / "Scripts" / "check-build-cache-paths.sh")],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        self.assertIn("aligned", result.stdout)

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

    def test_ci_assets_gate_locale_rerun(self) -> None:
        text = (ROOT / "Scripts" / "ci-assets-gate.sh").read_text(encoding="utf-8")
        self.assertIn("generate.sh --assets", text)
        self.assertIn("assert-generated-output.sh --assets", text)
        self.assertIn("LC_ALL=en_US.UTF-8", text)
        self.assertIn("LANG=en_US.UTF-8", text)

    def test_restore_and_build_action_owns_cache_prefix(self) -> None:
        text = (
            ROOT / ".github" / "actions" / "restore-and-build" / "action.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("build-cache-key", text)
        self.assertIn("build-for-testing.sh", text)
        self.assertIn("prune-derived-data-cache.sh", text)
        self.assertIn("default: './Scripts/build-for-testing.sh'", text)
        self.assertNotIn("default: './Scripts/build-for-testing.sh --app-only'", text)
        workflow = (ROOT / ".github" / "workflows" / "tests.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("restore-and-build", workflow)
        self.assertTrue(
            "./Scripts/test.sh unit" in workflow or "./Scripts/test-package.sh" in workflow,
            "unit job must invoke package tests via test.sh or test-package.sh",
        )
        self.assertNotIn("./Scripts/test.sh unit --no-build", workflow)
        self.assertIn("build-for-testing.sh --app-only", workflow)
        self.assertIn("fromJSON(needs.build.outputs.full-ui-matrix)", workflow)
        self.assertIn("preboot-simulator: 'true'", workflow)
        self.assertNotIn("checkout-ci", workflow)
        self.assertIn("Smoke tests (${{ matrix.name }})", workflow)
        self.assertIn("needs.changes.outputs.infra", workflow)
        self.assertNotIn("actions/cache/restore@", workflow)
        self.assertIn("stage-ci-test-artifact.sh", text)
        cache_key = (
            ROOT / ".github" / "actions" / "build-cache-key" / "action.yml"
        ).read_text(encoding="utf-8")
        self.assertIn('git rev-parse "HEAD:Raw Assets"', cache_key)
        checkout = (
            ROOT / ".github" / "actions" / "checkout-trinket" / "action.yml"
        ).read_text(encoding="utf-8")
        sparse_list = checkout.split("sparse-checkout: |", 1)[1].split("- name:", 1)[0]
        self.assertIn(".github", sparse_list)
        self.assertIn("StoreKit", sparse_list)
        self.assertNotIn("Raw Assets", sparse_list)

    def test_release_compile_is_required_only_for_nightly_and_manual_runs(self):
        workflow = (ROOT / ".github/workflows/tests.yml").read_text()
        release = workflow.split("  release-device:\n", 1)[1].split("  unit:\n", 1)[0]
        condition = next(line.strip()[4:] for line in release.splitlines() if line.strip().startswith("if: "))
        for event, expected in (("push", False), ("schedule", True), ("workflow_dispatch", True)):
            expression = condition.replace("github.event_name", repr(event)).replace("||", "or")
            self.assertEqual(eval(expression, {"__builtins__": {}}), expected)
        self.assertIn("timeout-minutes: 30", release)
        self.assertIn("./Scripts/build.sh --release-device --quiet", release)
        self.assertIn("SKIP_GENERATE: 1", release)
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
        self.assertIn('export DEVELOPER_DIR="$best_path/Contents/Developer"', setup)
        self.assertIn('echo "DEVELOPER_DIR=$DEVELOPER_DIR" >> "$GITHUB_ENV"', setup)
        job = (ROOT / ".github/actions/test-job/action.yml").read_text()
        self.assertIn("./Scripts/restore-ci-test-products.sh", job)
        self.assertLess(job.index("./Scripts/restore-ci-test-products.sh"), job.index("- name: Run tests"))

    def test_package_registry_has_no_compile_only_split(self) -> None:
        owner = (ROOT / "Scripts" / "build-inputs.env").read_text(encoding="utf-8")
        self.assertNotIn("TRINKET_COMPILE_ONLY_PACKAGES", owner)
        classifier = (ROOT / "Scripts" / "change-classification.sh").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("TRINKET_COMPILE_ONLY_PACKAGES", classifier)
        # The package membership gate must read the registry, not a
        # second hardcoded list that can drift from build-inputs.env.
        self.assertIn(
            '"${TRINKET_TEST_PACKAGES[@]}"',
            classifier,
        )

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
            generate = root / "Scripts/generate.sh"
            generate.write_text('#!/bin/bash\necho generated >> calls\n')
            generate.chmod(0o755)
            script = """
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
            ("Scripts/lib/media-assets.sh", "--assets"),
            ("Scripts/config/full-only-art-kinds.txt", "--assets"),
            ("Scripts/prepare-assets.sh", "--assets"),
        ):
            with self.subTest(path=relative), tempfile.TemporaryDirectory() as directory:
                root = self.make_repo_fixture(
                    directory, ("Scripts/build-freshness.sh", "Scripts/build-inputs.env"))
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
                    ["bash", "-ec", "source Scripts/build-freshness.sh; prepare_generated_inputs results"],
                    cwd=root, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((root / "calls").read_text(), expected)

    def test_asset_dispatch_validates_before_conversion(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(
                directory, ("Scripts/prepare-assets.sh", "Scripts/lib/args.sh"))
            for kind in ("art", "cinematic", "audio", "app-icon"):
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

    def test_test_package_records_timing_log(self) -> None:
        text = (ROOT / "Scripts" / "test-package.sh").read_text(encoding="utf-8")
        self.assertIn("test-timing.py record", text)
        self.assertIn('package:$package', text)
        self.assertIn('--run "$invocation_id"', text)
        self.assertIn("--xcresult", text)
        helpers = (ROOT / "Scripts" / "lib" / "test-helpers.sh").read_text(encoding="utf-8")
        test_text = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        combined = helpers + test_text
        self.assertIn('--run "$XCODE_RUNNER_INVOCATION_ID"', combined)

    def test_test_package_parallelizes_multiple_packages(self) -> None:
        # test-package.sh is the single owner of parallel package builds/tests:
        # per-package DerivedData tenants with SYMROOT/OBJROOT pins.
        text = (ROOT / "Scripts" / "test-package.sh").read_text(encoding="utf-8")
        self.assertIn("xargs -P", text)
        self.assertIn("package test schemes in parallel", text)
        self.assertIn("per-package DerivedData tenants", text)
        # Tenant pins live in one helper so the build-for-testing and test
        # branches cannot drift; test-package.sh only selects the action.
        self.assertIn('trinket_set_package_scheme_args "$scheme"', text)
        self.assertIn('"${TRINKET_PACKAGE_SCHEME_ARGS[@]}"', text)
        self.assertNotIn('SYMROOT=$(package_symroot "$package_dd")', text)
        stamp = (ROOT / "Scripts" / "build-freshness.sh").read_text(encoding="utf-8")
        self.assertIn("package_symroot()", stamp)
        self.assertIn("package_objroot()", stamp)
        self.assertIn("package_shared_precomps_dir()", stamp)
        self.assertIn("trinket_set_package_scheme_args()", stamp)
        self.assertIn("TRINKET_PACKAGE_SCHEME_ARGS", stamp)
        # Both branches share one invocation base: parallel targets and
        # hermetic package resolution live in the helper, not per-branch.
        self.assertIn("-parallelizeTargets", stamp)
        self.assertIn("-disableAutomaticPackageResolution", stamp)
        self.assertIn("Packages/.DerivedData", stamp)
        # build-for-testing.sh delegates package builds to the single parallel
        # owner instead of re-implementing the xargs/tenant protocol.
        build_for_testing = (ROOT / "Scripts" / "build-for-testing.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("test-package.sh --build-for-testing", build_for_testing)
        self.assertIn("TRINKET_BUILD_FINGERPRINTS_APP", build_for_testing)
        helpers = (ROOT / "Scripts" / "lib" / "test-helpers.sh").read_text(encoding="utf-8")
        self.assertNotIn("trinket_run_package_tests", helpers)
        test_sh = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        # test.sh unit collapses into one package-test pass via the parallel
        # owner: no separate generic prebuild, no orchestration helper.
        self.assertNotIn("trinket_run_package_tests", test_sh)
        self.assertNotIn("test-package.sh --build-for-testing", test_sh)
        self.assertIn('"${TRINKET_TEST_PACKAGES[@]}"', test_sh)

    def test_bare_full_ui_requires_explicit_opt_in(self) -> None:
        # Full exhaustive UI is CI-owned post-push; bare local runs must opt in.
        test_sh = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        self.assertIn('TRINKET_ALLOW_FULL_UI:-', test_sh)
        self.assertIn('GITHUB_ACTIONS:-}', test_sh)
        self.assertIn("Refusing a bare local full exhaustive UI run", test_sh)
        deploy = (ROOT / "Scripts" / "test-deploy.sh").read_text(encoding="utf-8")
        # Release-time deploy verification is the sanctioned bypass.
        self.assertIn("TRINKET_ALLOW_FULL_UI=1 ./Scripts/test.sh ui", deploy)

    def test_run_env_removes_shared_packages_derived_data(self) -> None:
        text = (ROOT / "Scripts" / "lib" / "derived-data.sh").read_text(encoding="utf-8")
        self.assertIn('Packages/.DerivedData', text)
        self.assertIn('rm -rf "$repo_root/Packages/.DerivedData"', text)


    def test_unit_dispatch_forwards_flags_and_exit_without_app_preparation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            scripts = Path(directory) / "Scripts"
            shutil.copytree(ROOT / "Scripts", scripts)
            (scripts / "run-env.sh").write_text('trinket_run_env_init() { exit 91; }\n')
            (scripts / "test-package.sh").write_text('#!/bin/bash\nprintf "%s\\n" "$@"\nexit 17\n')
            for flags in (("--no-build", "--verbose"), ("--quiet",)):
                result = subprocess.run([str(scripts / "test.sh"), "unit", *flags],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 17, result.stdout + result.stderr)
                args = result.stdout.splitlines()
                self.assertEqual(args[:len(flags)], list(flags))
                self.assertIn("BattleEngine", args)
                self.assertEqual(len(args), len(set(args)))


    def test_package_build_prepares_generated_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            scripts = Path(directory) / "Scripts"
            shutil.copytree(ROOT / "Scripts", scripts)
            (scripts / "run-env.sh").write_text(
                'trinket_run_env_init() { RESULTS_DIR="$PWD/results"; }\n'
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
                        capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 73, result.stdout + result.stderr)
                    self.assertIn("prepared inputs", result.stdout)



if __name__ == "__main__":
    unittest.main()
