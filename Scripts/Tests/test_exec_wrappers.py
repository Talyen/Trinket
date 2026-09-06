#!/usr/bin/env python3
"""Execution-free coverage for top-level wrappers lacking dedicated tests.

Covers --help/unknown-arg paths for test.sh, build-for-testing.sh,
test-scripts.sh, and performance.sh without requiring Xcode or simulators.
"""

import json
import os
import plistlib
import shutil
import tempfile
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
    def test_preflight_and_style_do_not_reserve_a_run(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            scripts = Path(directory) / "Scripts"
            shutil.copytree(ROOT / "Scripts", scripts)
            (scripts / "run-env.sh").write_text(
                'trinket_run_env_init() { echo "unexpected run reservation" >&2; exit 91; }\n'
            )
            (scripts / "lib/test-style.sh").write_text(
                'trinket_run_style_gate() { echo "style checked"; }\n'
            )
            cases = [
                (name, ["--help"], 0, "Usage:")
                for name in ("test.sh", "test-package.sh", "build-for-testing.sh")
            ] + [
                ("test.sh", ["style"], 0, "style checked"),
                ("build-for-testing.sh", ["--bad-option"], 1, "Unknown argument"),
                ("test-package.sh", ["--bad-option"], 1, "Unknown option"),
                ("test-package.sh", ["MissingPackage"], 1, "Unknown package"),
                ("test-package.sh", ["BattleEngine", "BattleEngine"], 1, "Duplicate package"),
                ("test-package.sh", ["--destination", "platform=macOS", "BattleEngine"], 1, "only platform=iOS Simulator"),
                ("test-package.sh", ["--destination", "generic/platform=macOS", "BattleEngine"], 1, "only platform=iOS Simulator"),
                ("test-package.sh", ["--destination", "", "BattleEngine"], 1, "requires a value"),
                ("test-package.sh", ["--destination", "platform=iOS,name=Phone", "BattleEngine"], 1, "only platform=iOS Simulator"),
                ("test-package.sh", ["--build-for-testing", "--destination", "id=fixture", "BattleEngine"], 1, "cannot be combined"),
            ]
            for name, args, status, message in cases:
                with self.subTest(name=name, args=args):
                    result = subprocess.run([str(scripts / name), *args], capture_output=True, text=True)
                    self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                    self.assertIn(message, result.stdout + result.stderr)

    def test_final_handoff_preview_does_not_execute_docs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            scripts = Path(directory) / "Scripts"
            shutil.copytree(ROOT / "Scripts", scripts)
            (scripts / "check-docs.py").write_text('raise SystemExit(91)\n')
            for flags, status in ((["--dry-run", "--final"], 0), (["--final"], 91)):
                with self.subTest(flags=flags):
                    result = subprocess.run(
                        [str(scripts / "handoff.sh"), *flags, "--paths", "Scripts/build.sh"],
                        capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                    if status == 0:
                        self.assertIn("python3 ./Scripts/check-docs.py --final", result.stdout)

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

    def test_simulator_launcher_installs_resolved_product_and_rejects_missing_outputs(self) -> None:
        for mode in ("valid", "missing-target", "missing-product", "missing-plist", "settings-failed"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                scripts = root / "Scripts"
                shutil.copytree(ROOT / "Scripts", scripts)
                (scripts / "lib/tools.sh").write_text('trinket_prepend_pinned_tools() { :; }\n')
                (scripts / "run-env.sh").write_text(
                    'trinket_run_env_init() { DERIVED_DATA_PATH="$PWD/agent-dd"; '
                    'RESULTS_DIR="$PWD/results"; mkdir -p "$RESULTS_DIR"; }\n'
                    'trinket_run_env_print() { :; }\n'
                )
                (scripts / "build-freshness.sh").write_text('prepare_generated_inputs() { :; }\n')
                (scripts / "ensure-simulator.sh").write_text(
                    'trinket_sim_slot_ensure() { :; }\n'
                    'ensure_test_simulator() { SIMULATOR_UDID=fixture; }\n'
                )
                (scripts / "xcode-runner.sh").write_text(
                    'source Scripts/lib/xcode-watchdog.sh\n'
                    'xcode_runner_run() { while [[ "$1" != -- ]]; do shift; done; shift; "$@"; }\n'
                )
                app = root / "custom products/Debug-iphonesimulator/Trinket.app"
                app.mkdir(parents=True)
                if mode != "missing-plist":
                    (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "fixture.trinket"}))
                if mode == "missing-product":
                    shutil.rmtree(app)
                settings = [{"target": "Dependency", "buildSettings": {}}]
                if mode != "missing-target":
                    settings.append({"target": "Trinket", "buildSettings": {
                        "TARGET_BUILD_DIR": str(app.parent), "FULL_PRODUCT_NAME": app.name,
                    }})
                (root / "settings.json").write_text(json.dumps(settings))
                (root / "mode").write_text(mode)
                binaries = root / "bin"
                binaries.mkdir()
                commands = {
                    "xcodebuild": r"""#!/usr/bin/env python3
import json, pathlib, sys
with pathlib.Path('build-args.jsonl').open('a') as handle:
    handle.write(json.dumps(sys.argv[1:]) + '\n')
if '-showBuildSettings' in sys.argv:
    if pathlib.Path('mode').read_text() == 'settings-failed':
        raise SystemExit(72)
    print(pathlib.Path('settings.json').read_text())
""",
                    "xcrun": """#!/usr/bin/env python3
import json, pathlib, sys
if sys.argv[1:3] == ['simctl', 'install']:
    pathlib.Path('install.json').write_text(json.dumps(sys.argv[3:]))
    raise SystemExit(73)
if 'appearance' in sys.argv:
    print('dark')
""",
                }
                for name, source in commands.items():
                    binary = binaries / name
                    binary.write_text(source)
                    binary.chmod(0o755)
                result = subprocess.run(
                    [str(scripts / "run-simulator.sh"), "--isolate"],
                    env={**os.environ, "PATH": str(binaries) + os.pathsep + os.environ["PATH"]},
                    capture_output=True, text=True,
                )
                calls = [json.loads(line) for line in (root / "build-args.jsonl").read_text().splitlines()]
                self.assertEqual(calls[0][0], "build")
                self.assertEqual(calls[1][:2], ["-showBuildSettings", "-json"])
                self.assertEqual(calls[0][1:], calls[1][2:])
                if mode == "valid":
                    self.assertEqual(result.returncode, 73, result.stdout + result.stderr)
                    self.assertEqual(json.loads((root / "install.json").read_text()), ["fixture", str(app)])
                else:
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertIn("could not resolve", result.stderr)
                    self.assertFalse((root / "install.json").exists())

    def test_performance_runner_retains_success_and_partial_failure_evidence(self) -> None:
        for test_status in (0, 1):
            with self.subTest(test_status=test_status), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                scripts = root / "Scripts"
                (scripts / "lib").mkdir(parents=True)
                for name in ("performance.sh", "collect-performance-results.py", "compare-performance.py", "performance_model.py", "lib/lock.sh"):
                    shutil.copy2(ROOT / "Scripts" / name, scripts / name)
                (scripts / "performance_environment.py").write_text(
                    "import pathlib, sys; pathlib.Path(sys.argv[1]).write_text('{}')\n"
                )
                baseline = root / "Performance/Baselines/simulator-60.json"
                baseline.parent.mkdir(parents=True)
                baseline.write_text(json.dumps({
                    "scenarios": ["navigation"], "mode": "observe",
                    "goals": {"minimumAverageFPS": 59, "minimumOnePercentLowFPS": 59, "maximumSevereStallCount": 0},
                }))
                report = {
                    "scenario": "navigation", "schemaVersion": 5, "iteration": 1,
                    "averageFPS": 30, "onePercentLowFPS": 20, "p95FrameMs": 50,
                    "p99FrameMs": 50, "maxFrameMs": 50, "missedDeadlineCount": 1,
                    "missedDeadlineRatio": 0.1, "severeStallCount": 1,
                }
                stub = scripts / "test.sh"
                stub.write_text(
                    '#!/bin/bash\nmkdir -p "$RESULTS_DIR"\n'
                    + 'cat > "$RESULTS_DIR/run.log" <<REPORT\n'
                    + "TRINKET_PERFORMANCE_REPORT " + json.dumps(report) + "\nREPORT\n"
                    + f"exit {test_status}\n"
                )
                stub.chmod(0o755)
                environment = {key: value for key, value in os.environ.items() if not key.startswith("TRINKET_PERFORMANCE_")}
                result = subprocess.run([str(scripts / "performance.sh")], env=environment, capture_output=True, text=True)
                self.assertEqual(result.returncode, test_status, result.stdout + result.stderr)
                reports = list((root / ".DerivedData/PerformanceResults").glob("*/reports.json"))
                self.assertEqual(len(reports), 1)
                self.assertEqual(len(json.loads(reports[0].read_text())["reports"]), 1)
                self.assertFalse((root / ".DerivedData/.performance.lock").exists())
                environment["TRINKET_PERFORMANCE_OUTPUT_DIR"] = str(reports[0].parent)
                reused = subprocess.run([str(scripts / "performance.sh")], env=environment, capture_output=True, text=True)
                self.assertNotEqual(reused.returncode, 0)
                self.assertIn("already exists", reused.stderr)

    def test_handoff_reports_outcome_after_all_checks_including_quiet_mode(self) -> None:
        for selected, cheap, expected in ((0, 0, 0), (7, 0, 1), (0, 8, 8)):
            with self.subTest(selected=selected, cheap=cheap), tempfile.TemporaryDirectory() as directory:
                scripts = Path(directory) / "Scripts"
                shutil.copytree(ROOT / "Scripts", scripts)
                (scripts / "test-scripts.sh").write_text(f"#!/bin/bash\necho selected-check\nexit {selected}\n")
                registry = scripts / "config/cheap-slices.txt"
                registry.write_text(f"echo cheap-check; exit {cheap}\n")
                result = subprocess.run(
                    [str(scripts / "handoff.sh"), "--quiet", "--paths", "Scripts/test-scripts.sh"],
                    env={**os.environ, "TRINKET_CHEAP_SLICES_CONFIG": str(registry)},
                    text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                if expected == 0:
                    self.assertTrue(result.stdout.strip().endswith("Handoff PASS: selected checks and cheap CI slices completed."))
                    self.assertLess(result.stdout.index("cheap-check"), result.stdout.index("Handoff PASS"))
                else:
                    self.assertNotIn("Handoff PASS", result.stdout)
                    self.assertIn("Handoff FAIL", result.stderr)
                    self.assertIn("./Scripts/test-scripts.sh" if selected else "cheap CI slices", result.stderr)
                    if selected:
                        self.assertNotIn("cheap-check", result.stdout)

    def test_script_failures_retain_bounded_evidence_and_exit_status(self) -> None:
        import sys
        payloads = {
            "python": "noise\n" * 100 + 'Traceback (most recent call last):\n  File "case.py", line 7\nAssertionError: expected price\n' + "z" * 2000 + "\nnoise\n" * 100,
            "shell": "noise\n" * 100 + "FAIL: expected retained evidence\n" + "z" * 2000 + "\nnoise\n" * 100,
            "unknown": "noise\n" * 100 + "last diagnostic\n",
            "success": "quiet successful details\n",
            "syntax": "syntax fixture",
        }
        for case, payload in payloads.items():
            with self.subTest(case=case), tempfile.TemporaryDirectory(prefix="script evidence ") as directory:
                root = Path(directory)
                scripts = root / "Scripts"
                for relative in ("lib", "config", "Tests"):
                    (scripts / relative).mkdir(parents=True)
                for name in ("test-scripts.sh", "lib/args.sh", "script_diagnostics.py", "diagnostic_limits.py", "config/diagnostic-limits.env"):
                    shutil.copy2(ROOT / "Scripts" / name, scripts / name)
                (scripts / "check-build-cache-paths.sh").write_text("#!/bin/bash\nexit 0\n")
                (scripts / "check-build-cache-paths.sh").chmod(0o755)
                (root / "payload").write_text(payload)
                (root / "bin").mkdir()
                stub = root / "bin/python3"
                stub.write_text(
                    '#!/bin/bash\nif [[ "$1" == -m ]]; then\n'
                    '  if [[ "$CASE" == python ]]; then cat "$PAYLOAD"; exit 7; fi\n'
                    '  exit 0\nfi\nexec "$REAL_PYTHON" "$@"\n'
                )
                stub.chmod(0o755)
                (scripts / "Tests/test-fixture.sh").write_text(
                    '#!/bin/bash\ncat "$PAYLOAD"\n[[ "$CASE" == success ]] && exit 0\nexit 9\n'
                )
                if case == "syntax":
                    (scripts / "Tests/test-fixture.sh").write_text("#!/bin/bash\nif broken\n")
                env = {**os.environ, "PATH": str(root / "bin") + ":" + os.environ["PATH"],
                       "CASE": case, "PAYLOAD": str(root / "payload"), "REAL_PYTHON": sys.executable,
                       "RESULTS_DIR": str(root / "retained logs")}
                result = subprocess.run([str(scripts / "test-scripts.sh"), "--skip-docs"], env=env, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0 if case == "success" else 7 if case == "python" else 2 if case == "syntax" else 9, result.stdout + result.stderr)
                if case == "success":
                    self.assertFalse(list((root / "retained logs").iterdir()))
                    self.assertNotIn(payload.strip(), result.stdout)
                    continue
                log = Path(next(line.removeprefix("Full log: ") for line in result.stderr.splitlines() if line.startswith("Full log: ")))
                if case == "syntax":
                    self.assertIn("syntax error", log.read_text())
                    self.assertIn("syntax error", result.stderr)
                    continue
                self.assertEqual(log.read_text(), payload)
                self.assertLessEqual(len(result.stderr.splitlines()), 63)
                excerpt = result.stderr.splitlines()[2:-1]
                self.assertTrue(all(len(line) <= 240 for line in excerpt))
                self.assertIn("output omitted", result.stderr)
                expected = {"python": "AssertionError: expected price", "shell": "FAIL: expected retained evidence", "unknown": "last diagnostic"}[case]
                self.assertIn(expected, result.stderr)
                if case == "python":
                    self.assertIn("Traceback", result.stderr)

    def test_help_exits_zero(self) -> None:
        for script, extra in (
            ("test.sh", []),
            ("build-for-testing.sh", []),
            ("test-scripts.sh", []),
            ("performance.sh", []),
        ):
            # performance.sh has no --help; it validates env first, so only
            # assert the wrappers that document --help here.
            if script == "performance.sh":
                continue
            result = run_script(script, "--help")
            self.assertEqual(result.returncode, 0, script + result.stderr)
            self.assertIn("Usage:", result.stdout, script)

    def test_unknown_arg_fails(self) -> None:
        for script in ("build-for-testing.sh", "test-scripts.sh"):
            result = run_script(script, "--definitely-not-a-flag")
            self.assertNotEqual(result.returncode, 0, script)
            self.assertIn("Unknown argument", result.stderr, script)

    def test_test_sh_unknown_option_fails(self) -> None:
        result = run_script("test.sh", "--definitely-not-a-flag")
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertIn("Unknown option", result.stderr)

    def test_simulator_names_single_sourced(self) -> None:
        config = (ROOT / "Scripts" / "config" / "simulator-names.env").read_text()
        self.assertIn("Trinket Run", config)
        self.assertIn("Trinket Agent", config)
        shell = (ROOT / "Scripts" / "lib" / "simctl.sh").read_text()
        self.assertIn("simulator-names.env", shell)
        python = (ROOT / "Scripts" / "simctl_json.py").read_text()
        self.assertIn("simulator-names.env", python)

    def test_destructive_git_commands_single_sourced(self) -> None:
        config = (ROOT / "Scripts" / "config" / "destructive-git-commands.txt").read_text()
        names = [line.strip() for line in config.splitlines() if line.strip() and not line.startswith("#")]
        self.assertEqual(names, ["reset", "checkout", "restore", "clean", "switch", "branch", "push"])
        shim = (ROOT / "Scripts" / "bin" / "git").read_text()
        self.assertIn("destructive-git-commands.txt", shim)
        guard = (ROOT / "Scripts" / "git-safety-guard.mjs").read_text()
        self.assertIn("destructive-git-commands.txt", guard)

    def test_format_roots_derived_from_packages(self) -> None:
        text = (ROOT / "Scripts" / "format-dirs.env").read_text()
        self.assertIn("TRINKET_TEST_PACKAGES", text)
        self.assertNotIn("Packages/TrinketCore/Tests", text)


if __name__ == "__main__":
    unittest.main()
