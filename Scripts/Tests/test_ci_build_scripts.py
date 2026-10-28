#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import time
import unittest

from script_test_support import ROOT, ScriptRegressionTestCase, run_captured, write_executable, write_json

from pathlib import Path

class CIBuildScriptTests(ScriptRegressionTestCase):
    def test_each_requested_ui_filter_requires_executed_cases(self) -> None:
        def case(identifier, result="Passed"):
            return {"nodeType": "Test Case", "nodeIdentifier": identifier, "result": result}

        # One owner covers both export and terminal fallback, including exact
        # selector boundaries. A passing neighbor must not hide a missing filter.
        bundle_cases = [
            ([case("ExampleTests/testOne()")], ["ExampleTests"], True),
            ([case("ExampleTests/testOne()")], ["TrinketUITests/ExampleTests/testOne"], True),
            ([case("ExampleTests/testOne()"), case("OtherTests/testOne()")], ["ExampleTests", "OtherTests"], True),
            ([case("ExampleTests/testOne()")], ["ExampleTests", "MissingTests"], False),
            ([case("ExampleTests/testOne()")], ["ExampleTests/testOther"], False),
            ([case("ExampleTestsExtra/testOne()")], ["ExampleTests"], False),
            ([case("ExampleTests/testOne()", "Skipped")], ["ExampleTests"], False),
            ([case("ExampleTests/testOne()", "Skipped"), case("OtherTests/testOne()")], ["ExampleTests"], False),
            ([case("ExampleTests/testOne()"), case("ExampleTests/testTwo()", "Skipped")], ["ExampleTests"], True),
            ([], ["ExampleTests"], False),
        ]
        command = '''
source Scripts/lib/test-helpers.sh
RESULT_BUNDLE_PATH=fixture
XCODEBUILD_LOG_PATH="$1"
shift
TARGETS=("$@")
xcode_runner_result_bundle_complete() { [[ "$RESULT_EVIDENCE" == bundle ]]; }
xcrun() { :; }
xcode_runner_run_bounded() { printf '%s' "$TEST_RESULTS"; }
trinket_assert_targeted_tests_executed
'''
        log_cases = [
            ("Test Case '-[TrinketUITests.ExampleTests testOne]' passed (1 seconds).", ["ExampleTests/testOne"], True),
            ("Test Case '-[TrinketUITests.ExampleTests testOne]' passed (1 seconds).", ["ExampleTests", "MissingTests"], False),
            ("Test Case '-[TrinketUITests.ExampleTests testOne]' skipped (1 seconds).", ["ExampleTests"], False),
            ("Test Case '-[TrinketUITests.ExampleTests testOne]' started.\nExecuted 1 test, with 0 failures", ["ExampleTests"], False),
        ]
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'tests.log'
            for evidence, cases in (("bundle", bundle_cases), ("log", log_cases)):
                for content, targets, succeeds in cases:
                    with self.subTest(evidence=evidence, content=content, targets=targets):
                        log.write_text(content if evidence == "log" else "")
                        payload = json.dumps({"testNodes": [{"nodeType": "Test Suite", "children": content}]}) if evidence == "bundle" else ""
                        result = run_captured(
                            ['bash', '-eu', '-c', command, '_', str(log), *targets], cwd=ROOT,
                            env={**os.environ, 'RESULT_EVIDENCE': evidence, 'TEST_RESULTS': payload},
                        )
                        self.assertEqual(result.returncode, 0 if succeeds else 1, result.stdout + result.stderr)
            for results, expected, succeeds in (
                ([case('ExampleTests/testOne'), case('ExampleTests/testTwo')], ['ExampleTests/testOne', 'ExampleTests/testTwo'], True),
                ([case('ExampleTests/testOne'), case('ExampleTests/testTwo', 'Skipped')], ['ExampleTests/testOne', 'ExampleTests/testTwo'], False),
                ([case('ExampleTests/testOne')], ['ExampleTests/testOne', 'ExampleTests/testTwo'], False),
                ([case('ExampleTests/testOne'), case('ExampleTests/testOne')], ['ExampleTests/testOne'], False),
                ([case('ExampleTests/testOne')], [], False),
                ([case('ExampleTests/testOne')], {'unexpected': True}, False),
            ):
                with self.subTest(deployment_expected=expected, results=results):
                    result = run_captured(
                        ['bash', '-eu', '-c', command, '_', str(log), 'ExampleTests'], cwd=ROOT,
                        env={**os.environ, 'RESULT_EVIDENCE': 'bundle',
                             'TEST_RESULTS': json.dumps({'testNodes': results}),
                             'TRINKET_DEPLOY_EXPECTED_CASES': json.dumps(expected)},
                    )
                    self.assertEqual(result.returncode, 0 if succeeds else 1, result.stdout + result.stderr)

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
                    write_executable(script, source)
                script = '''source Scripts/xcode-runner.sh
# Real helper deadlines have an independent owner in test-xcode-runner.sh.
# This matrix exercises execution evidence and manifests, without polling a fake tool.
xcode_runner_run_bounded() { shift; "$@"; }
xcode_runner_prepare unit "$PWD/results"
if [[ "$FAKE_SUMMARY" != null ]]; then
    mkdir -p "$XCODE_RUNNER_RESULT_BUNDLE_PATH"
    touch "$XCODE_RUNNER_RESULT_BUNDLE_PATH/Info.plist"
fi
xcrun() { printf '%s' "$FAKE_SUMMARY"; }
xcode_runner_run --quiet --label unit --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH" --log "$XCODE_RUNNER_LOG_PATH" --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" -- xcodebuild "$1"
'''
                result = run_captured(
                    ['/bin/bash', '-c', script, '_', action],
                    cwd=root,
                    env={
                        **self.verification_environment(),
                        'PATH': str(tools) + ':' + os.environ['PATH'],
                        'FAKE_LOG': log,
                        'FAKE_SUMMARY': json.dumps(summary),
                        'XCODE_RUNNER_REPORTER': str(tools / 'reporter'),
                        'TRINKET_XCODE_WALL_TIMEOUT_SECONDS': '0',
                        'TRINKET_XCODE_IDLE_TIMEOUT_SECONDS': '0',
                    },
                )
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
                 "Scripts/build-inputs.env", "Scripts/lib/generated-paths.sh",
                 "Scripts/config/generated-paths.tsv", ".github/actions/build-cache-key/action.yml"),
            )
            action = root / ".github/actions/build-cache-key/action.yml"
            live = action.read_text(encoding="utf-8")

            def run_checker() -> subprocess.CompletedProcess[str]:
                return run_captured([str(root / "Scripts/check-build-cache-paths.sh")], cwd=root)

            self.assertEqual(run_checker().returncode, 0)
            for glob in ('Trinket/**', 'StoreKit/**', 'ArtManifest/**', 'MusicManifest/**', 'SoundManifest/**',
                         'Packages/TrinketContent/Sources/TrinketContent/Generated/PreparedAssets.generated.json'):
                with self.subTest(exact_key_input=glob):
                    lines = live.splitlines(keepends=True)
                    full_index = next(i for i, line in enumerate(lines) if "full=" in line)
                    self.assertIn(f"'{glob}', ", lines[full_index])
                    lines[full_index] = lines[full_index].replace(f"'{glob}', ", "", 1)
                    action.write_text("".join(lines), encoding="utf-8")
                    result = run_checker()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(f"must include {glob}", result.stderr)

            for glob in ('Scripts/**', 'ContentManifest/**', 'Localization/**',
                         'StoreKit/**', 'ArtManifest/**', 'MusicManifest/**', 'SoundManifest/**',
                         'Packages/TrinketContent/Sources/TrinketContent/Generated/PreparedAssets.generated.json'):
                with self.subTest(glob=glob):
                    lines = live.splitlines(keepends=True)
                    nonsource_index = next(i for i, line in enumerate(lines) if "nonsource=" in line)
                    self.assertNotIn(glob, lines[nonsource_index])
                    lines[nonsource_index] = lines[nonsource_index].replace(
                        "hashFiles(", f"hashFiles('{glob}', ", 1
                    )
                    action.write_text("".join(lines), encoding="utf-8")
                    result = run_checker()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(f"must not include {glob}", result.stderr)

    def test_release_compile_is_required_only_for_nightly_and_manual_runs(self):
        workflow = (ROOT / ".github/workflows/tests.yml").read_text()
        release = workflow.split("  release-device:\n", 1)[1].split("  unit:\n", 1)[0]
        self.assertIn("needs: [changes, reuse]", release)
        self.assertNotIn("needs.unit", release)
        self.assertIn("github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'", release)
        self.assertNotIn("needs.build", release)
        self.assertIn("./Scripts/build.sh --release-device --quiet", release)
        self.assertIn("SKIP_GENERATE: 1", release)
        self.assertNotIn("timeout-minutes:", release)
        self.assertNotIn("TRINKET_XCODE_WALL_TIMEOUT_SECONDS", release)
        self.assertIn("if: failure()", release)
        self.assertIn("--stage-artifacts .DerivedData/TestResults .DerivedData/ReleaseResults-artifact", release)
        self.assertIn("path: .DerivedData/ReleaseResults-artifact", release)
        aggregate = workflow.split("  ci-ok:\n", 1)[1].split("  exhaustive-ok:\n", 1)[0]
        self.assertIn("release-device", aggregate.split("if: always()", 1)[0])
        command = aggregate.split("        run: |\n", 1)[1].split("\n  #", 1)[0]
        for outcome, status in (("success", 0), ("skipped", 0), ("failure", 1), ("cancelled", 1)):
            result = subprocess.run(["bash", "-ec", command], capture_output=True, cwd=ROOT,
                                    env={**os.environ, "REQUIRE_PARITY": "false", "JOB_RESULTS": json.dumps({
                                        "build": {"result": "success"}, "release-device": {"result": outcome}})})
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

    def test_full_ui_uses_ready_products_after_smoke_failure_without_masking_it(self):
        workflow = (ROOT / '.github/workflows/tests.yml').read_text()
        build = workflow.split('  build:\n', 1)[1].split('  release-device:\n', 1)[0]
        smoke = build.split('- name: Run smoke', 1)[1].split('- name: Run exhaustive', 1)[0]
        inline = build.split('- name: Run exhaustive', 1)[1].split('- name: Preserve required smoke failure', 1)[0]
        required_smoke = build.split('- name: Preserve required smoke failure', 1)[1]
        exhaustive = workflow.split('  exhaustive-ui:\n', 1)[1].split('  diff-review:\n', 1)[0]
        self.assertIn("upload-artifact: 'true'", build)
        self.assertNotIn('build-artifact:', smoke)
        self.assertIn('id: smoke', smoke)
        self.assertIn('continue-on-error: true', smoke)
        self.assertIn('products-outcome: ${{ steps.restore-and-build.outcome }}', build)
        self.assertIn('[[ "$OUTCOME" == success ]]', exhaustive)
        self.assertIn('OUTCOME: ${{ needs.build.outputs.inline-ui-outcome }}', exhaustive)
        aggregate = workflow.split('  ci-ok:\n', 1)[1].split('  exhaustive-ok:\n', 1)[0]
        self.assertIn('build', aggregate.split('if: always()', 1)[0])

        inline_condition = inline.split('if: ', 1)[1].splitlines()[0]
        smoke_condition = required_smoke.split('if: ', 1)[1].splitlines()[0]
        summary_condition = exhaustive.split('if: >-\n', 1)[1].split('    runs-on:', 1)[0].strip()
        self.assertIn('always()', inline_condition)
        self.assertIn('always()', summary_condition)
        for products, smoke_outcome, cancelled, requested, reused in (
            ('success', 'success', False, True, False),
            ('success', 'failure', False, True, False),
            ('failure', 'skipped', False, True, False),
            ('success', 'failure', True, True, False),
            ('success', 'failure', False, False, False),
            ('skipped', 'skipped', False, True, True),
            ('skipped', 'skipped', True, True, True),
        ):
            with self.subTest(products=products, smoke=smoke_outcome, cancelled=cancelled, requested=requested, reused=reused):
                values = {
                    'always()': True, '!cancelled()': not cancelled,
                    'inputs.include-exhaustive': requested,
                    'steps.restore-and-build.outcome': products, 'steps.smoke.outcome': smoke_outcome,
                    'needs.build.outputs.products-outcome': products, 'needs.build.result': smoke_outcome,
                    'needs.reuse.result': 'success', 'needs.reuse.outputs.standard': 'true' if reused else 'false',
                    'github.event_name': 'schedule', 'needs.changes.outputs.code': 'true',
                }

                def enabled(expression):
                    for key, value in values.items():
                        expression = expression.replace(key, repr(value))
                    return eval(' '.join(expression.replace('&&', 'and').replace('||', 'or').split()), {'__builtins__': {}}, {})

                expected = requested and products == 'success' and not cancelled
                self.assertEqual(enabled(inline_condition), expected)
                self.assertEqual(enabled(summary_condition), requested and not cancelled and (products == 'success' or reused))
                self.assertEqual(enabled(smoke_condition), smoke_outcome == 'failure' and not cancelled)
        command = required_smoke.split('        run: |\n', 1)[1]
        result = run_captured(['bash', '-ec', command], cwd=ROOT)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)

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
                write_executable(
                    root / "Scripts/generate.sh",
                    '#!/bin/bash\n[[ ("$*" == "" || "$*" == "--assets") && "$TRINKET_FORCE_ABILITY_DUMP" == 1 ]] || exit 9\nprintf called >> calls\n' + generator + "\n",
                )
                identifier = "A" * 24
                (root / "Trinket.xcodeproj/project.pbxproj").write_text(
                    "Begin PBXNativeTarget section\n"
                    + identifier + " /* target */\nEnd PBXNativeTarget section\n"
                )
                write_json(root / "Smoke.xctestplan", {"identifier": identifier})
                (root / "output").write_text(initial)
                stamp = root / "results/.last-generate.stamp"
                stamp.touch()
                os.utime(stamp, (time.time() + 60, time.time() + 60))
                result = run_captured(["bash", "Scripts/assert-generated-output.sh", "--idempotent"], cwd=root)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                self.assertEqual((root / "calls").read_text(), "called")

    def test_generation_reuses_dirty_inputs_and_detects_edits_and_deletions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(
                directory, ("Scripts/build-freshness.sh", "Scripts/build-inputs.env",
                            "Scripts/lib/generated-paths.sh", "Scripts/config/generated-paths.tsv"))
            write_executable(
                root / 'Scripts/prepare-assets.sh',
                '#!/bin/bash\n[[ "$*" == "--heal" ]] && exit 0\n[[ "$*" == "--check --outputs-only" ]] || exit 9\n[[ ! -f invalid-assets ]] || exit 7\nprintf checked >> asset-checks\n',
            )
            write_executable(root / "Scripts/generate.sh", '#!/bin/bash\necho generated >> calls\n')
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
            run_captured(["bash", "-eu", "-c", script], cwd=root, expected=0)

    def test_generation_tracks_shared_generator_helpers(self) -> None:
        cases = (
            ("Scripts/lib/project-generation.sh", ""),
            ("Scripts/tool-versions.env", ""),
            ("Scripts/lib/ci-tools.d/xcodegen.sh", ""),
            ("Trinket.xcodeproj/project.pbxproj", ""),
            ("Scripts/internal/content/content_codegen_modifiers.py", "--skip-xcodegen"),
            ("Scripts/internal/content/content_codegen_triggers.py", "--skip-xcodegen"),
            ("Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityCatalog.swift", "--skip-xcodegen"),
            ("Packages/TrinketContent/Sources/TrinketContent/Encounters/Mystery/MysteryEventPool+Events.swift", "--skip-xcodegen"),
            ("Packages/TrinketContent/Sources/TrinketContent/Encounters/Mystery/RecruitEventPool.swift", "--skip-xcodegen"),
            ("Scripts/prepare-media.py", ""),
            ("Scripts/config/full-only-art-kinds.txt", ""),
            ("Scripts/prepare-assets.sh", ""),
        )
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(
                directory, ("Scripts/build-freshness.sh", "Scripts/build-inputs.env",
                            "Scripts/lib/generated-paths.sh", "Scripts/config/generated-paths.tsv"))
            for relative in ("ContentManifest/input.tsv", "ArtManifest/input.tsv", "project.yml", *(path for path, _ in cases)):
                (root / relative).parent.mkdir(parents=True, exist_ok=True)
                (root / relative).touch()
            (root / 'cases').write_text(''.join(f'{path}|{expected}\n' for path, expected in cases))
            # Prove each path invalidates the real grouped fingerprints, without
            # repeating the full generation pipeline. Output-repair tests below
            # own content-only, project-only, and combined dispatch/stamping.
            run_captured(["bash", "-eu", "-c", '''
source Scripts/build-freshness.sh
snapshots() {
    generation_input_snapshots "${content_generation_inputs[@]}" -- "${project_generation_inputs[@]}" -- "${asset_generation_inputs[@]}"
}
while IFS='|' read -r relative expected; do
    { read -r content_before; read -r project_before; read -r assets_before; } < <(snapshots)
    touch "$relative"
    { read -r content_after; read -r project_after; read -r assets_after; } < <(snapshots)
    if [[ "$expected" == --skip-xcodegen ]]; then
        [[ "$content_before" != "$content_after" && "$project_before" == "$project_after" && "$assets_before" == "$assets_after" ]] && continue
    else
        [[ "$project_before" != "$project_after" || "$assets_before" != "$assets_after" ]] && continue
    fi
    echo "Wrong generation input groups for $relative (expected '$expected')" >&2
    exit 1
done < cases
'''], cwd=root, expected=0)

    def test_preparation_repairs_changed_or_missing_generated_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(directory, (
                "Scripts/build-freshness.sh", "Scripts/build-inputs.env", "Scripts/lib/generated-paths.sh",
            ))
            (root / "Scripts/config").mkdir()
            (root / "Scripts/config/generated-paths.tsv").write_text(
                "content|Generated/Catalog.swift\nproject|Trinket/Info.plist\n"
            )
            write_executable(root / "Scripts/prepare-assets.sh", '#!/bin/bash\nexit 0\n')
            write_executable(
                root / "Scripts/generate.sh",
                '#!/bin/bash\nset -eu\nprintf "%s\\n" "$*" >> calls\n'
                'mkdir -p Generated Trinket Trinket.xcodeproj/xcshareddata/xcschemes\n'
                'printf catalog > Generated/Catalog.swift\n'
                'if [[ "$*" != --skip-xcodegen ]]; then\n'
                '  printf plist > Trinket/Info.plist\n'
                '  printf scheme > Trinket.xcodeproj/xcshareddata/xcschemes/Trinket.xcscheme\nfi\n',
            )
            run_captured(["bash", "-eu", "-c", '''
unset TRINKET_SHARED_DERIVED_DATA SKIP_GENERATE
source Scripts/build-freshness.sh
prepare_generated_inputs results
prepare_generated_inputs results
[[ $(wc -l < calls) -eq 1 ]]
printf damaged > Generated/Catalog.swift
prepare_generated_inputs results
[[ $(cat Generated/Catalog.swift) == catalog ]]
rm Generated/Catalog.swift
prepare_generated_inputs results
[[ $(cat Generated/Catalog.swift) == catalog ]]
rm Trinket/Info.plist
prepare_generated_inputs results
[[ $(cat Trinket/Info.plist) == plist ]]
rm Generated/Catalog.swift Trinket/Info.plist
prepare_generated_inputs results
[[ $(cat Generated/Catalog.swift) == catalog && $(cat Trinket/Info.plist) == plist ]]
rm -r Trinket.xcodeproj/xcshareddata
prepare_generated_inputs results
[[ -f Trinket.xcodeproj/xcshareddata/xcschemes/Trinket.xcscheme ]]
prepare_generated_inputs results
'''], cwd=root, expected=0)
            self.assertEqual((root / "calls").read_text().splitlines(),
                             ["", "--skip-xcodegen", "--skip-xcodegen", "", "", ""])

    def test_asset_dispatch_validates_before_conversion(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(
                directory, ("Scripts/prepare-assets.sh", "Scripts/lib/args.sh"))
            (root / 'Scripts/asset-library.py').write_text('import sys\nsys.exit(0)\n')
            for kind in ("art", "audio", "app-icon"):
                pipeline = root / "Scripts" / f"prepare-{kind}-assets.sh"
                if kind == "app-icon":
                    pipeline = root / "Scripts/prepare-app-icon.sh"
                write_executable(pipeline, '#!/bin/bash\nprintf "%s %s\\n" "$0" "$*" >> calls\n')
            for arguments in (("--kind", "typo"), ("--kind", "art", "extra"), ("--kind",)):
                with self.subTest(arguments=arguments):
                    result = run_captured(["bash", "Scripts/prepare-assets.sh", *arguments], cwd=root)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse((root / "calls").exists())
            result = run_captured(["bash", "Scripts/prepare-assets.sh", "--kind", "sfx"], cwd=root, expected=0)
            self.assertEqual((root / "calls").read_text(), "Scripts/prepare-audio-assets.sh sfx\n")

    def test_bare_full_ui_requires_explicit_opt_in(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(directory, (
                'Scripts/test.sh', 'Scripts/lib/args.sh', 'Scripts/lib/verification-policy.sh',
            ))
            scripts = root / 'Scripts'
            # Stop at preparation, before any real build or simulator operation.
            (scripts / 'run-env.sh').write_text(
                'trinket_run_env_init() { touch prepared; return 99; }\n')
            (scripts / 'build-freshness.sh').touch()
            (scripts / 'xcode-runner.sh').touch()
            (scripts / 'phase-timing.py').write_text('print(0)\n')
            for targets, hosted, full_ui, expected in (
                ([], False, '', 1),
                (['BattleFlowUITests'], False, '', 99),
                ([], False, '1', 99),
                ([], True, '', 99),
            ):
                with self.subTest(targets=targets, hosted=hosted, full_ui=full_ui):
                    prepared = root / 'prepared'
                    prepared.unlink(missing_ok=True)
                    result = run_captured(['bash', 'Scripts/test.sh', 'ui', *targets], cwd=root,
                        env=self.verification_environment(hosted=hosted, TRINKET_ALLOW_HEAVY_LOCAL='1',
                                                          RYAN_HEAVY_LANE_ACTIVE='fixture',
                                                          TRINKET_ALLOW_FULL_UI=full_ui))
                    self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                    self.assertEqual(prepared.exists(), expected == 99)

    def test_unit_dispatch_forwards_flags_and_exit_without_app_preparation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(directory, (
                "Scripts/test.sh", "Scripts/build-freshness.sh", "Scripts/build-inputs.env",
                "Scripts/lib/generated-paths.sh", "Scripts/config/generated-paths.tsv",
                "Scripts/lib/args.sh", "Scripts/xcode-runner.sh", "Scripts/config/diagnostic-limits.env",
                "Scripts/lib/xcode-manifest.sh", "Scripts/lib/xcode-watchdog.sh",
            ))
            scripts = root / "Scripts"
            (scripts / "run-env.sh").write_text('trinket_run_env_init() { exit 91; }\n')
            write_executable(scripts / "test-package.sh", '#!/bin/bash\nprintf "%s\\n" "$@"\nexit 17\n')
            for flags in (("--no-build", "--verbose"), ("--quiet",)):
                result = run_captured([str(scripts / "test.sh"), "unit", *flags], env={**os.environ, "GITHUB_ACTIONS": "true"}, expected=17)
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
                    result = run_captured([str(scripts / "test-package.sh"), *action, "BattleEngine"], env={**os.environ, "GITHUB_ACTIONS": "true"}, expected=73)
                    self.assertIn("prepared inputs", result.stdout)



if __name__ == "__main__":
    unittest.main()
