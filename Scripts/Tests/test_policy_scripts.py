from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/agent-watch-ci.sh',
    'Scripts/check-api-bans.sh',
    'Scripts/check-module-boundaries.sh',
    'Scripts/ci-infra-rerun.sh',
    'Scripts/config/infrastructure-patterns.env',
    'Scripts/lib/infrastructure-patterns.sh',
    'Scripts/format-dirs.env',
    'Scripts/release-notes.sh',
    'Scripts/check-agent-invariants.sh',
    'Scripts/check-exclusivity-footguns.sh',
    'Scripts/lib/rg-check.sh',
    'Scripts/lib/test-style.sh',
)

from pathlib import Path
import os
import shutil
import json
import subprocess
import tempfile
from script_test_support import ScriptRegressionTestCase, ROOT


class PolicyScriptsTests(ScriptRegressionTestCase):
    def test_ci_watch_dispatch_requires_readable_job_evidence_for_the_requested_branch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fake_gh = root / 'gh'
            fake_gh.write_text('''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
if args[:2] == ['repo', 'view']:
    print('fixture/repo')
elif args[:2] == ['run', 'list']:
    if '--branch' not in args or args[args.index('--branch') + 1] != 'fixture-branch':
        sys.exit(91)
    print('10')
elif args[:2] == ['run', 'view']:
    if args[args.index('--json') + 1] == 'status,conclusion,jobs':
        print(json.dumps(dict(status='completed', conclusion='success', jobs=[])))
    elif os.environ['FIXTURE_JOBS'] == 'unavailable':
        sys.exit(1)
    else:
        print(os.environ['FIXTURE_JOBS'])
elif args[:2] == ['workflow', 'run']:
    open(os.environ['FIXTURE_DISPATCH'], 'w').write('dispatched')
    sys.exit(77)
else:
    sys.exit(92)
''')
            fake_gh.chmod(0o755)
            cases = (
                ('unavailable', False, 1), ('{}', False, 1), ('{"jobs":[]}', False, 1),
                ('{"jobs":[{}]}', False, 1),
                (json.dumps({'jobs': [{'name': 'changes / Path filter', 'conclusion': 'success'}]}), True, 77),
                (json.dumps({'jobs': [{'name': 'tests / gate', 'conclusion': 'success'}]}), False, 0),
            )
            for jobs, dispatch, status in cases:
                with self.subTest(jobs=jobs):
                    dispatched = root / 'dispatched'
                    dispatched.unlink(missing_ok=True)
                    result = subprocess.run(
                        [str(ROOT / 'Scripts/agent-watch-ci.sh'), '--ref', 'fixture-branch',
                         '--no-infra-rerun', '--poll-seconds', '1'], cwd=ROOT,
                        env={**os.environ, 'PATH': f"{root}:{os.environ['PATH']}",
                             'FIXTURE_JOBS': jobs, 'FIXTURE_DISPATCH': str(dispatched)},
                        capture_output=True, text=True, timeout=10,
                    )
                    self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                    self.assertEqual(dispatched.exists(), dispatch)

    def test_ci_infrastructure_retry_requires_evidence_for_every_failed_job(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fake_gh = root / "gh"
            fake_gh.write_text('''#!/usr/bin/env python3
import json, os, subprocess, sys
args = sys.argv[1:]
jobs = json.loads(os.environ['FIXTURE_JOBS'])
logs = json.loads(os.environ['FIXTURE_LOGS'])
if args[:2] == ['repo', 'view']:
    print('fixture/repo')
elif args[:2] == ['run', 'rerun']:
    open(os.environ['FIXTURE_RERUN'], 'w').write('rerun')
elif '--json' in args:
    payload = {'jobs': [dict(j, databaseId=j['id'], conclusion=j.get('conclusion', 'failure')) for j in jobs]}
    result = subprocess.run(['jq', '-r', args[args.index('--jq') + 1]],
                            input=json.dumps(payload), text=True)
    sys.exit(result.returncode)
elif args[:1] == ['api']:
    if '/actions/runs/' in args[1]:
        print('\\n'.join(str(j['id']) for j in jobs))
elif '--log-failed' in args:
    if '--job' in args:
        key = args[args.index('--job') + 1]
        if key not in logs:
            sys.exit(1)
        print(logs[key])
    else:
        print('\\n'.join(logs.values()))
else:
    sys.exit(1)
''')
            fake_gh.chmod(0o755)
            infra = 'Unable to boot simulator'
            cases = (
                ([{'id': 1, 'name': 'Build for testing'}], {'1': infra}, True),
                ([{'id': 1, 'name': 'Smoke UI'}], {'1': infra}, True),
                ([{'id': 1, 'name': 'Smoke'}, {'id': 2, 'name': 'Generate and style', 'conclusion': 'success'}],
                 {'1': infra}, True),
                ([], {}, False),
                ([{'id': 1, 'name': 'Smoke'}, {'id': 2, 'name': 'Unit'}],
                 {'1': infra, '2': 'XCTAssertEqual failed'}, False),
                ([{'id': 1, 'name': 'Smoke'}, {'id': 2, 'name': 'Generate and style'}],
                 {'1': infra, '2': 'format failed'}, False),
                ([{'id': 1, 'name': 'Unit'}], {'1': infra + '\nXCTAssertEqual failed'}, False),
                ([{'id': 1, 'name': 'Build for testing'}],
                 {'1': 'Ability.swift:42:2: error: failed to launch macro plugin'}, False),
                ([{'id': 1, 'name': 'Unit'}],
                 {'1': infra + '\nAbility.swift:42: error: cannot find type in scope'}, False),
                ([{'id': 1, 'name': 'Unit'}], {'1': infra + '\n✘ Suite Combat failed after 1 second.'}, False),
                ([{'id': 1, 'name': 'Smoke'}], {'1': infra + "\nTest Case '-[ShopTests purchase]' failed (0.1 seconds)."}, False),
                ([{'id': 1, 'name': 'Smoke'}], {}, False),
                ([{'id': 1, 'name': 'Smoke'}], {'1': infra + '\n' + 'progress\n' * 9000}, True),
                ([{'id': 1, 'name': 'Smoke'}],
                 {'1': 'XCTAssertEqual failed\n' + 'progress\n' * 9000 + infra}, False),
            )
            for jobs, logs, retry in cases:
                with self.subTest(jobs=jobs, log_sizes={key: len(value) for key, value in logs.items()}):
                    rerun = root / 'rerun'
                    rerun.unlink(missing_ok=True)
                    result = subprocess.run(
                        [str(ROOT / 'Scripts/ci-infra-rerun.sh'), '--run-id', '123', '--rerun'], cwd=ROOT,
                        env={**os.environ, 'PATH': f"{root}:{os.environ['PATH']}",
                             'FIXTURE_JOBS': json.dumps(jobs), 'FIXTURE_LOGS': json.dumps(logs),
                             'FIXTURE_RERUN': str(rerun)}, capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 0 if retry else 1, result.stdout + result.stderr)
                    self.assertEqual(rerun.exists(), retry)

    def test_shell_policy_checks_reject_search_errors(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake_rg = Path(directory) / "rg"
            fake_rg.write_text('#!/bin/sh\nexit "$SEARCH_STATUS"\n')
            fake_rg.chmod(0o755)
            for name in ("api-bans", "agent-invariants", "exclusivity-footguns", "module-boundaries"):
                for status in (1, 2):
                    with self.subTest(check=name, status=status):
                        result = subprocess.run(
                            [str(ROOT / f"Scripts/check-{name}.sh")], cwd=ROOT,
                            env={**os.environ, "PATH": f"{directory}:{os.environ['PATH']}", "SEARCH_STATUS": str(status)},
                            capture_output=True, text=True,
                        )
                        self.assertEqual(result.returncode, 0 if status == 1 else 2, result.stdout + result.stderr)


    def test_module_boundaries_reject_upward_imports_and_allowlist_battle_seams(self) -> None:
        manifest = (
            "// swift-tools-version: 6.4\n"
            "import PackageDescription\n"
            "let package = Package(name: \"Probe\", targets: [.target(name: \"Probe\")])\n"
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("check-module-boundaries.sh", "lib/rg-check.sh"):
                target = root / "Scripts" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, target)
            for package in ("TrinketDesignSystem", "BattleEngine", "TrinketPersistence",
                            "TrinketFeatureSupport", "TrinketBattleFeature", "TrinketAppState"):
                (root / "Packages" / package / "Sources" / package).mkdir(parents=True)
                (root / "Packages" / package / "Package.swift").write_text(manifest)
            contracts = root / "Packages/TrinketFeatureSupport/Sources/TrinketFeatureContracts/Probe.swift"
            contracts.parent.mkdir(parents=True)
            design_probe = root / "Packages/TrinketDesignSystem/Sources/Probe.swift"
            graph_probe = root / "Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveGraph/Probe.swift"
            graph_probe.parent.mkdir(parents=True)
            appstate_manifest = root / "Packages/TrinketAppState/Package.swift"
            seam = root / "Trinket/Features/Play/PlayView.swift"
            outsider = root / "Trinket/Features/Play/OutsiderView.swift"
            seam.parent.mkdir(parents=True)
            clean = (
                (design_probe, "struct Probe {}\n"),
                (graph_probe, "package final class SaveRoot {}\nextension SaveRoot {}\n"),
                (contracts, "import BattleEngine\nstruct Contract {}\n"),
                (seam, "import TrinketBattleFeature\nstruct PlayView {}\n"),
                (outsider, "struct OutsiderView {}\n"),
                (appstate_manifest, manifest),
            )
            appstate_dep = manifest.replace(
                '[.target(name: "Probe")]',
                '[.target(name: "Probe", dependencies: ["TrinketBattleFeature"])]',
            )
            cases = (
                ("clean tree with allowlisted seam", (), None),
                ("public mutable storage model",
                 ((graph_probe, "public final class SaveRoot {}\n"),),
                 "persistence graph must not export public"),
                ("public storage mapping extension",
                 ((graph_probe, "public extension SaveRoot {}\n"),),
                 "persistence graph must not export public"),
                ("contracts importing persistence",
                 ((contracts, "import TrinketPersistence\nstruct Contract {}\n"),),
                 "TrinketFeatureContracts must not import TrinketPersistence"),
                ("design system importing engine",
                 ((design_probe, "import BattleEngine\nstruct Probe {}\n"),),
                 "TrinketDesignSystem must not import BattleEngine"),
                ("app screen outside the battle seams",
                 ((outsider, "import TrinketBattleFeature\nstruct OutsiderView {}\n"),),
                 "must use BattleRuntime/FeatureSupport instead of importing BattleFeature"),
                ("app state depending on battle feature",
                 ((appstate_manifest, appstate_dep),),
                 "production target must depend on FeatureContracts, not BattleFeature"),
            )
            for label, overwrites, failure in cases:
                with self.subTest(label=label):
                    for path, source in clean:
                        path.write_text(source)
                    for path, source in overwrites:
                        path.write_text(source)
                    result = subprocess.run([str(root / "Scripts/check-module-boundaries.sh")],
                                            cwd=root, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 1 if failure else 0, result.stdout + result.stderr)
                    if failure:
                        self.assertIn(failure, result.stderr)


    def test_style_gate_runs_all_checks_and_preserves_an_earlier_failure(self) -> None:
        checks = ('format.sh', 'lint.sh', 'check-ui-style.py', 'check-api-bans.sh',
                  'check-exclusivity-footguns.sh', 'check-agent-invariants.sh', 'check-accessibility-ids.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'Scripts'
            (scripts / 'lib').mkdir(parents=True)
            shutil.copy2(ROOT / 'Scripts/lib/test-style.sh', scripts / 'lib/test-style.sh')
            for name in checks:
                path = scripts / name
                if name.endswith('.py'):
                    path.write_text('import os, sys\nfrom pathlib import Path\n'
                                    'with Path("calls").open("a") as log: log.write(Path(__file__).name + "\\n")\n'
                                    'sys.exit(7 if os.environ.get("FAILING_CHECK") == Path(__file__).name else 0)\n')
                else:
                    path.write_text('#!/bin/sh\nprintf "%s\\n" "${0##*/}" >> calls\n'
                                    '[ "${FAILING_CHECK:-}" != "${0##*/}" ] || exit 7\n')
                path.chmod(0o755)
            for scope, failing in (('', ''), (' Probe.swift', checks[0]), ('', checks[-1])):
                with self.subTest(scope=scope, failing=failing):
                    (root / 'calls').unlink(missing_ok=True)
                    result = subprocess.run(
                        ['bash', '-ec', 'source Scripts/lib/test-style.sh; trinket_run_style_gate' + scope],
                        cwd=root, env={**os.environ, 'FAILING_CHECK': failing}, capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 7 if failing else 0, result.stdout + result.stderr)
                    self.assertEqual((root / 'calls').read_text().splitlines(), list(checks))
