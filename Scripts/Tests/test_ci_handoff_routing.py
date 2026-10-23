#!/usr/bin/env python3

from __future__ import annotations

import re
import shlex
import shutil
import unittest
from unittest.mock import patch
import contextlib
import io
import json

from script_test_support import ROOT, ScriptRegressionTestCase, run_captured, write_executable

import os
import tempfile
from pathlib import Path

class CIHandoffRoutingTests(ScriptRegressionTestCase):
    def test_local_slices_follow_inputs_and_hosted_or_unknown_scope_keeps_full_registry(self) -> None:
        from internal.change_routing import classify, verification_plan
        commands = lambda paths, hosted=False: [check.command.partition(' --paths ')[0] for check in verification_plan(
            classify(paths), environment=self.verification_environment(hosted=hosted)) if check.id.startswith('cheap-')]
        self.assertEqual(commands(['Docs/Platform/Verification.md']), [])
        shop = commands(['Packages/TrinketPersistence/Sources/TrinketPersistence/Encounters/ShopPurchaseApplier.swift'])
        self.assertIn('./Scripts/check-module-boundaries.sh', shop)
        self.assertIn('python3 Scripts/localization.py check', shop)
        self.assertNotIn('./Scripts/check-artwork-budget.sh', shop)
        self.assertNotIn('./Scripts/release-notes.sh validate', shop)
        artwork = commands(['Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Artwork/PreparedArtworkCache.swift'])
        self.assertNotIn('./Scripts/check-artwork-budget.sh', artwork)
        full = commands(['Scripts/internal/change_routing.py'])
        self.assertEqual(commands(['unknown-input.config']), full)
        self.assertEqual(commands(['Unknown/Probe.swift', 'Docs/README.md']), full)
        self.assertEqual(commands(['.githooks/pre-push']), full)
        self.assertEqual(commands(['Docs/Platform/Verification.md'], hosted=True), full)
        self.assertIn('./Scripts/release-notes.sh validate', commands(['CHANGELOG.md']))
        selected = ['Packages/TrinketPersistence/Sources/TrinketPersistence/Progression/BattleRewardClaim.swift']
        local = verification_plan(classify(selected), environment=self.verification_environment())
        localization = next(check for check in local if 'Scripts/localization.py' in check.argv)
        self.assertEqual(localization.argv[-2:], ('--paths', *selected))

    def test_explicit_routes_select_only_the_requested_work_and_isolate_by_default(self) -> None:
        from script_test_support import load_script
        verify = load_script('explicit_route_verifier', 'verify.py')
        cases = (
            (['--package', 'TrinketCore'], ('./Scripts/test-package.sh', 'TrinketCore')),
            (['--route', 'focused', '--package', 'TrinketCore'], ('./Scripts/test-package.sh', 'TrinketCore')),
            (['--route', 'diagnostic', '--package', 'TrinketCore'], ('./Scripts/test-package.sh', 'TrinketCore')),
            (['--route', 'diagnostic', '--app-only'], ('./Scripts/test.sh', 'unit', '--app-only')),
            (['--route', 'diagnostic', '--ui', 'SmokeShopTests/testPurchase'], ('./Scripts/test.sh', 'smoke', 'SmokeShopTests/testPurchase')),
            (['--route', 'diagnostic', '--ui', 'OptionsUITests'], ('./Scripts/test.sh', 'ui', 'OptionsUITests')),
            (['--route', 'visual'], ('./Scripts/run-simulator.sh', '--isolate', '--inspect')),
            (['--route', 'release'], ('./Scripts/test-deploy.sh', '--mode', 'ui')),
        )
        for arguments, expected in cases:
            with self.subTest(arguments=arguments), patch.dict(os.environ, self.verification_environment(TRINKET_ALLOW_HEAVY_LOCAL="1"), clear=True), \
                 patch.object(verify, 'run_checks', return_value=0) as execute, \
                 patch.object(verify, 'save_report'), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(verify.main([*arguments, '--quiet', '--paths', 'Docs/README.md']), 0)
                checks = execute.call_args.args[0]
                self.assertEqual([check.argv for check in checks], [expected])
                environment = execute.call_args.kwargs['environment']
                self.assertEqual(environment['TRINKET_ISOLATE'], '1')
                self.assertEqual(environment['TRINKET_ALLOW_HEAVY_LOCAL'], '1')
                if arguments[1] == 'visual':
                    self.assertFalse(execute.call_args.kwargs['quiet'])
                if arguments[1] == 'release':
                    self.assertEqual(environment['TRINKET_ALLOW_FULL_UI'], '1')
        with contextlib.redirect_stderr(io.StringIO()):
            for arguments in (['--route', 'diagnostic'], ['--route', 'focused'], ['--route', 'static', '--package', 'TrinketCore'], ['--route', 'visual', '--smoke'], ['--package', 'Unknown'], ['--package', 'TrinketCore', 'TrinketCore']):
                with self.assertRaises(SystemExit):
                    verify.main([*arguments, '--paths', 'Docs/README.md'])

    def test_automatic_checks_defer_all_compilation_even_with_inherited_override(self) -> None:
        from internal.change_routing import automatic_plan, classify
        cases = (
            ['Packages/TrinketPersistence/Sources/TrinketPersistence/Probe.swift',
             'Packages/TrinketAppState/Sources/TrinketAppState/Probe.swift'],
            ['Packages/TrinketContent/Sources/TrinketContentTestSupport/CombatantFixtures.swift'],
            ['Trinket/Features/Play/PlayBrowsingStack.swift'],
            ['project.yml'],
            ['Packages/TrinketCore/Package.swift'],
        )
        for paths in cases:
            for flag in ('', '1'):
                with self.subTest(paths=paths, flag=flag):
                    checks = automatic_plan(classify(paths), environment=self.verification_environment(TRINKET_ALLOW_HEAVY_LOCAL=flag))
                    compiled = [check for check in checks if check.id in {'build', 'package', 'smoke', 'generate', 'assert'} or check.id.startswith('package:')]
                    self.assertTrue(compiled)
                    self.assertTrue(all(check.deferred for check in compiled))
                    self.assertFalse(any('TRINKET_ALLOW_HEAVY_LOCAL' in dict(check.environment) for check in checks))
        docs = automatic_plan(classify(['Docs/README.md']), environment=self.verification_environment())
        self.assertFalse(any(check.id in {'build', 'package'} or check.id.startswith('package:') for check in docs))
        hosted = automatic_plan(classify(cases[0]), environment=self.verification_environment(hosted=True))
        self.assertTrue(any(check.id == 'package' and not check.deferred for check in hosted))

    def test_public_api_consumer_checks_remain_visible_as_hosted_obligations(self) -> None:
        from internal.change_routing import automatic_plan, classify, Check
        from script_test_support import load_script
        verify = load_script('automatic_compilation_verifier', 'verify.py')
        route = classify(['Packages/TrinketCore/Sources/TrinketCore/Probe.swift'])
        route.features.add('public-api')
        checks = automatic_plan(route, environment=self.verification_environment())
        build = next(check for check in checks if check.id == 'build')
        self.assertEqual(build.argv, ('./Scripts/test.sh', 'unit', '--app-only'))
        self.assertTrue(build.deferred)
        for identifier in ('build', 'package:TrinketCore'):
            outcomes = {}
            with patch.object(verify.shutil, 'which', return_value=None), patch.object(verify.subprocess, 'run') as execute, contextlib.redirect_stderr(io.StringIO()):
                status = verify.run_checks([Check(identifier, 'compilation', ('must-not-run',))], outcomes=outcomes)
            self.assertEqual(status, 2)
            self.assertEqual(outcomes, {identifier: 'unavailable'})
            execute.assert_not_called()

    def test_routine_execution_never_probes_xcode_or_selects_local_compilation(self) -> None:
        from script_test_support import load_script
        verify = load_script('static_execution_verifier', 'verify.py')
        for route in ([], ['--route', 'static', '--smoke']):
            with self.subTest(route=route), patch.dict(os.environ, self.verification_environment(TRINKET_ALLOW_HEAVY_LOCAL='1'), clear=True), \
                 patch.object(verify, 'run_checks', return_value=0) as execute, \
                 patch.object(verify, 'save_report'), patch.object(verify, 'toolchain_identity') as toolchain, \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(verify.main([*route, '--quiet', '--paths',
                    'Trinket/App/TrinketApp.swift', 'Packages/TrinketCore/Package.swift']), 0)
                checks = execute.call_args.args[0]
                compiled = [check for check in checks if check.id in {'build', 'package', 'smoke', 'generate', 'assert'} or check.id.startswith('package:')]
                self.assertTrue(compiled)
                self.assertTrue(all(check.deferred for check in compiled))
                toolchain.assert_not_called()

    def test_local_selectors_require_opt_in_before_toolchain_or_workload_preparation(self) -> None:
        from script_test_support import load_script
        verify = load_script('opt_in_verifier', 'verify.py')
        for arguments in (['--package', 'TrinketCore'], ['--app-only'], ['--ui', 'SmokeShopTests'], ['--route', 'release']):
            with self.subTest(arguments=arguments), patch.dict(os.environ, self.verification_environment(), clear=True), \
                 patch.object(verify, 'run_checks') as execute, patch.object(verify, 'toolchain_identity') as toolchain, \
                 contextlib.redirect_stderr(io.StringIO()) as errors:
                with self.assertRaises(SystemExit) as failure:
                    verify.main([*arguments, '--paths', 'Docs/README.md'])
                self.assertEqual(failure.exception.code, 2)
                self.assertIn('expressly requested local', errors.getvalue())
                execute.assert_not_called()
                toolchain.assert_not_called()
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(verify.main([*arguments, '--dry-run', '--paths', 'Docs/README.md']), 0)
                execute.assert_not_called()

    def test_explicit_package_batch_runs_each_registered_package_once(self) -> None:
        from script_test_support import load_script
        verify = load_script('package_batch_verifier', 'verify.py')
        with patch.dict(os.environ, self.verification_environment(TRINKET_ALLOW_HEAVY_LOCAL='1'), clear=True), patch.object(verify, 'run_checks', return_value=0) as execute, patch.object(verify, 'save_report'), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(verify.main(['--package', 'TrinketCore', 'TrinketPersistence', '--paths', 'Docs/README.md']), 0)
        self.assertEqual([check.argv for check in execute.call_args.args[0]],
                         [('./Scripts/test-package.sh', 'TrinketCore'), ('./Scripts/test-package.sh', 'TrinketPersistence')])
        self.assertEqual(execute.call_args.kwargs['environment']['TRINKET_PACKAGE_TEST_JOBS'], '1')

    def test_durable_reports_preserve_failed_deferred_and_unrun_evidence_without_preview_artifacts(self) -> None:
        from script_test_support import load_script
        from internal.change_routing import Check
        verify = load_script('durable_evidence_verifier', 'verify.py')
        checks = [Check('docs', 'documentation', ('unused',)),
                  Check('package', 'package tests', ('unused',), deferred=True),
                  Check('later', 'later check', ('unused',))]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'README.md').write_text('source at verification time')
            with contextlib.redirect_stdout(io.StringIO()):
                report = verify.save_report(root, 'static', ['README.md'], checks, {'docs': 'failed'}, 1)
            value = json.loads(report.read_text())
            self.assertEqual(value['exit_status'], 1)
            self.assertEqual([item['outcome'] for item in value['checks']], ['failed', 'deferred to CI', 'not run'])
            self.assertIsNone(value['commit'])
            self.assertTrue(value['inputs']['README.md'])
            report.unlink()
            with patch.object(verify, 'save_report') as save, contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(verify.main(['--dry-run', '--paths', 'Docs/README.md']), 0)
                save.assert_not_called()

    def test_evidence_summary_never_promotes_preview_deferred_or_unrun_checks(self) -> None:
        from script_test_support import load_script
        from internal.change_routing import Check
        verify = load_script('evidence_verifier', 'verify.py')
        checks = [Check('docs', 'documentation', ('unused',)),
                  Check('build', 'app compilation', ('unused',), deferred=True),
                  Check('package', 'package tests', ('unused',), deferred=True)]
        for preview, outcomes, status in ((True, {}, 0), (False, {'docs': 'failed'}, 1),
                                           (False, {'docs': 'passed', 'build': 'deferred to CI', 'package': 'deferred to CI'}, 0)):
            with contextlib.redirect_stdout(io.StringIO()) as output:
                verify.report_evidence(checks, outcomes, preview=preview, status=status)
            text = output.getvalue()
            self.assertIn('App compilation: ' + ('deferred to CI' if preview or not status else 'not run'), text)
            self.assertNotIn('App compilation: passed', text)
            self.assertNotIn('Package compilation and behavior: passed', text)
            if preview:
                self.assertIn('Static checks: planned', text)
            elif status:
                self.assertIn('Static checks: failed', text)
                self.assertIn('resolve failed/unavailable', text)
            else:
                self.assertIn('Static checks: passed', text)
                self.assertIn('authorized push', text)

    def test_gemfile_changes_select_script_regressions(self) -> None:
        for hosted in (False, True):
            for path in ("Gemfile", "Gemfile.lock"):
                with self.subTest(path=path, hosted=hosted):
                    result = run_captured([str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--route", "static", "--paths", path], cwd=ROOT, env=self.verification_environment(hosted=hosted), expected=0)
                    flag = "" if hosted else " --fast"
                    self.assertIn(f"./Scripts/test-scripts.sh{flag} --paths {path}", result.stdout)

    def test_mixed_script_and_product_scope_keeps_narrow_regressions(self) -> None:
        script_only = run_captured(["python3", "Scripts/script_test_selection.py", "--paths", "Scripts/check-links.py"], cwd=ROOT, expected=0)
        for hosted in (False, True):
            with self.subTest(hosted=hosted):
                result = run_captured(
                    [str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--route", "static", "--paths", "Scripts/check-links.py", "Packages/TrinketCore/Sources/TrinketCore/Keyword.swift"],
                    cwd=ROOT,
                    env=self.verification_environment(hosted=hosted),
                    expected=0,
                )
                command = next(line.strip() for line in result.stdout.splitlines()
                               if line.strip().startswith("./Scripts/test-scripts.sh "))
                arguments = shlex.split(command)
                self.assertEqual('--fast' in arguments, not hosted)
                paths = arguments[arguments.index('--paths') + 1:]
                selected = run_captured(["python3", "Scripts/script_test_selection.py", "--paths", *paths], cwd=ROOT, expected=0)
                self.assertEqual(selected.stdout, script_only.stdout)

    def test_product_routes_preserve_package_and_smoke_owners(self) -> None:
        support = "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport"
        feature = "Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features"
        cases = (
            (["Trinket/Features/Play/Mystery/MysteryChoiceCard.swift"], None, "SmokeShellTests"),
            (["Trinket/Features/Play/Modes/PlayModeHubView.swift"], None, "SmokeShellTests"),
            ([f"{support}/Shared/HomesteadResourceArtwork.swift"], "TrinketFeatureSupport", None),
            ([f"{support}/Accessibility/AccessibilityID.swift"], "TrinketFeatureSupport", "SmokeShellTests"),
            ([f"{support}/Artwork/PreparedArtwork.swift"], "TrinketFeatureSupport", "SmokeShellTests"),
            ([f"{feature}/Effects/CombatantCardDeathEffectVariants.swift"], "TrinketBattleFeature", "SmokeBattleTests"),
            ([f"{feature}/Battlefield/BattleCombatantPane.swift"], "TrinketBattleFeature", "SmokeBattleTests"),
            ([f"{feature}/Effects/CombatantCardDeathEffectVariants.swift",
              f"{feature}/Battlefield/BattleCombatantPane.swift"], "TrinketBattleFeature", "SmokeBattleTests"),
            (["Packages/TrinketFeatureSupport/Sources/TrinketFeatureContracts/BattleRuntime.swift"], "TrinketFeatureSupport", None),
        )
        for paths, package, smoke in cases:
            with self.subTest(paths=paths):
                result = run_captured([str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--route", "static", *(["--smoke"] if smoke else []), "--paths", *paths], cwd=ROOT, expected=0)
                commands = [line.strip().removeprefix("SKIP_GENERATE=1 ") for line in result.stdout.splitlines()]
                if package:
                    self.assertEqual(commands.count(f"./Scripts/test-package.sh {package}"), 1)
                    self.assertFalse(any("--build-only" in command for command in commands))
                if package == "TrinketFeatureSupport" and smoke is None:
                    self.assertNotIn("./Scripts/build.sh", commands)
                if smoke:
                    self.assertIn(smoke, result.stdout)

    def test_missing_check_retains_failure_evidence_and_stops_before_later_checks(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'Scripts'
            shutil.copytree(ROOT / 'Scripts', scripts, ignore=shutil.ignore_patterns('__pycache__'))
            (scripts / 'test-scripts.sh').unlink()
            write_executable(scripts / 'cheap-fixture.sh', '#!/bin/bash\nprintf ran > later-check\n')
            (scripts / 'config/cheap-slices.txt').write_text('./Scripts/cheap-fixture.sh\n')
            run_captured(
                [str(scripts / 'handoff.sh'), '--quiet', '--paths', 'Scripts/test-scripts.sh'],
                env=self.verification_environment(RESULTS_DIR=str(root / '.DerivedData/HandoffResults')),
                expected=2,
            )
            self.assertFalse((root / 'later-check').exists())
            logs = list((root / '.DerivedData/HandoffResults').glob('handoff.*/phase-*.log'))
            self.assertEqual(len(logs), 1)
            self.assertIn('Could not start', logs[0].read_text())

    def test_style_preview_and_execution_preserve_literal_file_arguments(self) -> None:
        import json
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'Scripts'
            shutil.copytree(ROOT / 'Scripts', scripts, ignore=shutil.ignore_patterns('__pycache__'))
            path = 'Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/Probe $cash; literal.swift'
            source = root / path
            source.parent.mkdir(parents=True)
            source.write_text('struct Probe {}')
            (scripts / 'test.sh').write_text('#!/usr/bin/env python3\nimport json, pathlib, sys\npathlib.Path("arguments.json").write_text(json.dumps(sys.argv[1:]))\n')
            write_executable(scripts / 'cheap-fixture.sh', '#!/bin/bash\nexit 0\n')
            (scripts / 'config/cheap-slices.txt').write_text('./Scripts/cheap-fixture.sh\n')
            command = [str(scripts / 'handoff.sh'), '--quiet', '--route', 'static', '--paths', path]
            preview = run_captured([command[0], '--dry-run', *command[1:]], env=self.verification_environment(), expected=0)
            style = next(line.strip() for line in preview.stdout.splitlines() if line.strip().startswith('./Scripts/test.sh style'))
            run_captured(command, env=self.verification_environment(), expected=0)
            self.assertEqual(json.loads((root / 'arguments.json').read_text()), ['style', path])
            self.assertEqual(shlex.split(style)[1:], ['style', path])

    def test_shared_fixture_verification_routes(self) -> None:
        content_support = "Packages/TrinketContent/Sources/TrinketContentTestSupport"
        combatant = f"{content_support}/CombatantFixtures.swift"
        item = f"{content_support}/ItemFixtures.swift"
        party = f"{content_support}/BattlePartyFixtures.swift"
        consumers = {"BattleEngine", "TrinketAppState", "TrinketBattleFeature", "TrinketFeatureSupport"}
        cases = [
            ("combatant", [combatant], consumers | {"TrinketContent"}, False, False),
            ("item", [item], consumers | {"TrinketContent"}, False, False),
            ("party", [party], consumers | {"TrinketContent"}, False, False),
            ("content-manifest", ["Packages/TrinketContent/Package.swift"], {"TrinketContent"}, False, True),
            ("deleted", [f"{content_support}/DeletedFixture.swift"], consumers | {"TrinketContent"}, False, False),
            ("deduplicated", [combatant, item, party, "Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift"], consumers | {"TrinketContent"}, False, False),
            ("mixed-app", [party, "Trinket/App/TrinketApp.swift"], consumers | {"TrinketContent"}, True, False),
            ("docs", ["Docs/Platform/Testing.md"], set(), False, False),
        ]
        for name, paths, expected_packages, app_build, generation in cases:
            with self.subTest(case=name):
                result = run_captured([str(ROOT / "Scripts/handoff.sh"), "--isolate", "--dry-run", "--route", "static", "--smoke", "--paths", *paths], cwd=ROOT, expected=0)
                plan = result.stdout
                package_commands = re.findall(r"^\s*(?:SKIP_GENERATE=1 )?\./Scripts/test-package\.sh (.+)$", plan, re.MULTILINE)
                packages = [package for command in package_commands for package in command.split()]
                self.assertEqual(set(packages), expected_packages)
                self.assertEqual(len(packages), len(expected_packages))
                self.assertEqual("./Scripts/build.sh" in plan, app_build and shutil.which("xcodebuild") is not None)
                self.assertEqual("./Scripts/generate.sh" in plan, generation)
                self.assertEqual("./Scripts/assert-generated-output.sh --idempotent" in plan, generation)
                self.assertNotIn("./Scripts/test.sh smoke", plan)
                if name == "docs":
                    self.assertIn("./Scripts/check-docs.py", plan)
                    self.assertNotIn("./Scripts/test.sh style", plan)

    def test_handoff_reports_unavailable_compilation_after_available_checks(self) -> None:
        from script_test_support import load_script
        verify = load_script('fixture_verifier', 'verify.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'Scripts'
            shutil.copytree(ROOT / 'Scripts', scripts, ignore=shutil.ignore_patterns('__pycache__'))
            source = root / 'Trinket/App/ContentView.swift'
            source.parent.mkdir(parents=True)
            source.write_text('struct ContentView {}')
            (scripts / 'test.sh').write_text('#!/bin/bash\nprintf style > checks\n')
            (scripts / 'config/cheap-slices.txt').write_text('./Scripts/cheap-fixture.sh\n')
            write_executable(scripts / 'cheap-fixture.sh', '#!/bin/bash\nprintf cheap >> checks\n')
            for dry in (False, True):
                with patch.dict(os.environ, self.verification_environment(hosted=True), clear=True), patch.object(verify.shutil, 'which', return_value=None), contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()) as errors:
                    status = verify.main(['--quiet', *(['--dry-run'] if dry else []), '--paths', 'Trinket/App/ContentView.swift'], root=root)
                self.assertEqual(status, 0 if dry else 2)
                self.assertNotIn('Handoff PASS', output.getvalue())
                if dry:
                    self.assertIn('Unavailable required check', output.getvalue())
                else:
                    self.assertIn('INCOMPLETE', errors.getvalue())
                    self.assertEqual((root / 'checks').read_text(), 'stylecheap')

    def test_handoff_reports_outcome_after_all_checks_including_quiet_mode(self) -> None:
        for selected, cheap, expected in ((0, 0, 0), (7, 0, 7), (0, 8, 8)):
            with self.subTest(selected=selected, cheap=cheap), tempfile.TemporaryDirectory() as directory:
                scripts = Path(directory) / "Scripts"
                shutil.copytree(ROOT / "Scripts", scripts, ignore=shutil.ignore_patterns("__pycache__"))
                payload = "selected-check\n" * 200 + "FAIL: fixture diagnostic\n" if selected else "selected-check\n"
                (scripts / "test-scripts.sh").write_text(f"#!/bin/bash\ncat <<'PAYLOAD'\n{payload}PAYLOAD\nexit {selected}\n")
                registry = scripts / "config/cheap-slices.txt"
                write_executable(scripts / 'cheap-fixture.sh', f'#!/bin/bash\necho cheap-check\nexit {cheap}\n')
                registry.write_text('./Scripts/cheap-fixture.sh\n')
                result = run_captured(
                    [str(scripts / "handoff.sh"), "--quiet", "--paths", "Scripts/test-scripts.sh"],
                    env={
                        **os.environ,
                        "TRINKET_CHEAP_SLICES_CONFIG": str(registry),
                        "GITHUB_ACTIONS": "true",
                        "RESULTS_DIR": str(Path(directory) / ".DerivedData/HandoffResults"),
                        "TRINKET_CLEANUP_TEST_ARTIFACTS": "1",
                        "TRINKET_KEEP_REPORTS": "0",
                    },
                )
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                if expected == 0:
                    self.assertTrue(result.stdout.strip().endswith("Handoff PASS: selected local checks completed; hosted verification remains pending."))
                    self.assertLess(result.stdout.index("Handoff phase PASS: cheap CI slice"), result.stdout.index("Handoff PASS"))
                    self.assertNotIn("selected-check", result.stdout)
                    self.assertNotIn("cheap-check", result.stdout)
                    logs = Path(next(line.removeprefix("Handoff logs: ") for line in result.stdout.splitlines()
                                     if line.startswith("Handoff logs: ")))
                    self.assertFalse(logs.exists(), "successful output must be removed after the outcome")
                else:
                    self.assertNotIn("Handoff PASS", result.stdout)
                    self.assertIn("Handoff FAIL", result.stderr)
                    self.assertIn("./Scripts/test-scripts.sh" if selected else "./Scripts/cheap-fixture.sh", result.stderr)
                    log = Path(next(line.removeprefix("Full log: ") for line in result.stderr.splitlines()
                                    if line.startswith("Full log: ")))
                    self.assertEqual(log.read_text(), payload if selected else "cheap-check\n")
                    self.assertLess(len(result.stderr.splitlines()), 70)
                    retry = next(line.removeprefix('Rerun: ') for line in result.stderr.splitlines() if line.startswith('Rerun: '))
                    self.assertEqual(shlex.split(retry), ['./Scripts/handoff.sh', '--quiet', '--paths', 'Scripts/test-scripts.sh'])
                    if selected:
                        self.assertIn("FAIL: fixture diagnostic", result.stderr)
                        self.assertIn("output omitted", result.stderr)
                    if selected:
                        self.assertNotIn("cheap-check", result.stdout)

if __name__ == "__main__":
    unittest.main()
