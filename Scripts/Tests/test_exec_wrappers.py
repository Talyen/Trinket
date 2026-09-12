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
import signal
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
    def test_cheap_slices_require_a_readable_nonempty_registry(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            registry = Path(directory) / "slices"
            script = 'source Scripts/lib/cheap-slices.sh; TRINKET_CHEAP_SLICES_CONFIG="$1"; trinket_run_cheap_slices'
            for content, status in ((None, 1), ("# empty\n", 1), ("exit 17\n", 17), ("true\n", 0)):
                if content is not None:
                    registry.write_text(content)
                result = subprocess.run(["bash", "-eu", "-c", script, "_", str(registry)], cwd=ROOT, capture_output=True, text=True)
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)

    def test_git_setup_preserves_foreign_wrappers_and_updates_owned_wrappers(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            scripts.mkdir()
            shutil.copy2(ROOT / "Scripts/setup-git-safety.mjs", scripts)
            home = root / "home"
            wrapper = home / ".local/bin/git"
            wrapper.parent.mkdir(parents=True)
            (root / ".envrc").write_text(str(scripts / "bin"))
            environment = {**os.environ, "HOME": str(home)}
            for previous in ("#!/bin/sh\necho custom git\n", None,
                             "#!/bin/sh\n# Global harness-agnostic shim: if inside Trinket repo, delegate to repo guard\nold\n"):
                if previous is None:
                    wrapper.unlink()
                else:
                    wrapper.write_text(previous)
                result = subprocess.run(["node", str(scripts / "setup-git-safety.mjs")],
                                        env=environment, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                if previous and "custom git" in previous:
                    self.assertEqual(wrapper.read_text(), previous)
                else:
                    self.assertIn(str(scripts / "bin/git"), wrapper.read_text())
                    self.assertNotIn("\nold\n", wrapper.read_text())

    def test_tool_updates_leave_pins_untouched_after_download_or_hash_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            scripts.mkdir()
            for name in ("update-tools.sh", "tool-versions.env"):
                shutil.copy2(ROOT / "Scripts" / name, scripts)
            pins = scripts / "tool-versions.env"
            initial = pins.read_bytes()
            curl = root / "curl"
            curl.write_text('#!/bin/bash\nif [[ "$*" == *api.github.com* ]]; then echo \'{"tag_name":"999.0.0"}\'; exit 0; fi\nexit "$DOWNLOAD_STATUS"\n')
            curl.chmod(0o755)
            hasher = root / "shasum"
            hasher.write_text('#!/bin/bash\nexit 7\n')
            hasher.chmod(0o755)
            for download, expected in ((22, 22), (0, 7)):
                result = subprocess.run([str(scripts / "update-tools.sh"), "--apply"],
                                        env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}",
                                             "DOWNLOAD_STATUS": str(download)}, capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                self.assertEqual(pins.read_bytes(), initial)

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

    def test_handoff_reports_unavailable_compilation_after_available_checks(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            shutil.copytree(ROOT / "Scripts", scripts)
            source = root / "Trinket/App/ContentView.swift"
            source.parent.mkdir(parents=True)
            source.write_text("struct ContentView {}")
            (scripts / "test.sh").write_text('#!/bin/bash\n./Scripts/check-api-bans.sh\necho style-checked\n')
            (scripts / "check-api-bans.sh").write_text('#!/bin/bash\necho api >> checks\n')
            (scripts / "config/cheap-slices.txt").write_text('./Scripts/check-api-bans.sh\necho cheap-checked\n')
            startup = root / "startup"
            startup.write_text('command() { if [[ "$*" == "-v xcodebuild" ]]; then return 1; fi; builtin command "$@"; }\n')
            environment = {**os.environ, "BASH_ENV": str(startup)}
            for dry in (False, True):
                result = subprocess.run([str(scripts / "handoff.sh"), *(["--dry-run"] if dry else []),
                                         "--paths", "Trinket/App/ContentView.swift"],
                                        env=environment, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0 if dry else 2, result.stdout + result.stderr)
                self.assertNotIn("Handoff PASS", result.stdout)
                if dry:
                    self.assertIn("Unavailable required check", result.stdout)
                else:
                    self.assertIn("style-checked", result.stdout)
                    self.assertIn("cheap-checked", result.stdout)
                    self.assertIn("INCOMPLETE", result.stderr)
                    self.assertEqual((root / "checks").read_text(), "api\n")

    def test_worktree_remove_preserves_unregistered_directories(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            scripts = root / "Scripts"
            scripts.mkdir()
            shutil.copy2(ROOT / "Scripts/agent-worktree.mjs", scripts)
            worktree = root / ".worktrees/task"
            worktree.mkdir(parents=True)
            evidence = worktree / "unfinished.txt"
            evidence.write_text("work in progress")
            fake_git = root / "git"
            fake_git.write_text('#!/bin/sh\nprintf "worktree %s/task-other\\0\\0" "$FIXTURE_WORKTREES"\nexit "${FIXTURE_GIT_STATUS:-0}"\n')
            fake_git.chmod(0o755)
            for task, status in (("!!!", "0"), ("task", "0"), ("task", "1")):
                with self.subTest(task=task, status=status):
                    worktree.mkdir(parents=True, exist_ok=True)
                    evidence.write_text("work in progress")
                    result = subprocess.run(
                        ["node", str(scripts / "agent-worktree.mjs"), "remove", "--task", task],
                        env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}",
                             "FIXTURE_WORKTREES": str(root / ".worktrees"), "FIXTURE_GIT_STATUS": status},
                        capture_output=True, text=True,
                    )
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(evidence.read_text(), "work in progress")

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
                for name in ("test.sh", "test-package.sh", "build-for-testing.sh", "generate.sh")
            ] + [
                ("generate.sh", ["--force-xcodegen", "--help"], 0, "Usage:"),
                ("generate.sh", ["--bad-option"], 1, "Unknown argument"),
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
                for name in ("performance.sh", "collect-performance-results.py", "compare-performance.py", "internal/performance/performance_model.py", "lib/lock.sh"):
                    (scripts / name).parent.mkdir(parents=True, exist_ok=True)
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
                for name in ("test-scripts.sh", "script_test_selection.py", "lib/args.sh", "script_diagnostics.py", "internal/diagnostics/diagnostic_limits.py", "config/diagnostic-limits.env"):
                    (scripts / name).parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(ROOT / "Scripts" / name, scripts / name)
                (scripts / "check-build-cache-paths.sh").write_text("#!/bin/bash\nexit 0\n")
                (scripts / "check-build-cache-paths.sh").chmod(0o755)
                (root / "payload").write_text(payload)
                (scripts / "Tests/test_fixture.py").write_text("")
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

    def test_git_guard_refuses_without_changing_target_repository(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
            env.update(REAL_GIT="/usr/bin/git", GIT_OPTIONAL_LOCKS="0")
            def git(*args):
                return subprocess.check_output(["/usr/bin/git", *args], cwd=root, env=env)
            git("init", "-q")
            (root / "tracked").write_text("original")
            git("add", "tracked")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                "-c", "core.hooksPath=/dev/null", "commit", "-qm", "baseline")
            (root / "tracked").write_text("staged")
            git("add", "tracked")
            (root / "tracked").write_text("unstaged")
            (root / "untracked").write_text("unfinished")
            index = (root / ".git/index").read_bytes()
            for prefix in ([], ["-C", str(root)], ["-c", "core.quotepath=false", "-C", str(root)]):
                result = subprocess.run([str(ROOT / "Scripts/bin/git"), *prefix, "reset", "--hard"],
                                        cwd=root, env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual((root / "tracked").read_text(), "unstaged")
                self.assertEqual((root / "untracked").read_text(), "unfinished")
                self.assertEqual((root / ".git/index").read_bytes(), index)
                self.assertEqual(git("stash", "list"), b"")

    def test_chained_locks_preserve_quoted_cleanup_paths(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = root / "owner's resources.lock"
            second = root / "second.lock"
            script = '''
source Scripts/lib/lock.sh
trinket_dir_lock_acquire "$1" 0
trinket_dir_lock_acquire "$2" 0
'''
            result = subprocess.run(["bash", "-eu", "-c", script, "_", str(first), str(second)],
                                    cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse(first.exists())
            self.assertFalse(second.exists())

    def test_cancellation_stops_workers_before_releasing_resources(self) -> None:
        for owner in ("lock", "run-env"):
            for sig in (signal.SIGINT, signal.SIGTERM):
                with self.subTest(owner=owner, signal=sig), tempfile.TemporaryDirectory() as directory:
                    script = '''
source Scripts/run-env.sh
trap 'test ! -e "$resource"; ! kill -0 "$worker" 2>/dev/null' EXIT
if [[ "$1" == lock ]]; then
  resource="$2/generation.lock"
  trinket_dir_lock_acquire "$resource" 0
else
  TRINKET_REPO_ROOT="$2"
  TRINKET_ISOLATE=1
  trinket_run_env_init
  resource="$TRINKET_SIM_SLOT_PATH"
fi
bash -c 'trap "" INT TERM; while :; do sleep 1; done' &
worker=$!
printf '%s\\n' "$resource"
wait "$worker"
echo continued > "$2/continued"
'''
                    env = {key: value for key, value in os.environ.items()
                           if not key.startswith("TRINKET_") and key not in {"DERIVED_DATA_PATH", "RESULTS_DIR"}}
                    process = subprocess.Popen(["bash", "-eu", "-c", script, "_", owner, directory],
                                               cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                    resource = Path(process.stdout.readline().strip())
                    self.assertTrue(resource.exists())
                    process.send_signal(sig)
                    stdout, stderr = process.communicate(timeout=10)
                    self.assertEqual(process.returncode, 128 + sig, stdout + stderr)
                    self.assertFalse(resource.exists())
                    self.assertFalse((Path(directory) / "continued").exists())

    def test_mirror_uses_its_build_and_only_the_human_simulator(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            shutil.copytree(ROOT / "Scripts", scripts)
            calls = root / "calls"
            (scripts / "build.sh").write_text('#!/bin/bash\nprintf "build\\n" >> "$MIRROR_CALLS"\nexit "$BUILD_STATUS"\n')
            app = root / ".DerivedData/runs/agent-1/Build/Products/Debug-iphonesimulator/Trinket.app"
            app.mkdir(parents=True)
            (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "fixture.app"}))
            other = root / ".DerivedData/runs/agent-2/Build/Products/Debug-iphonesimulator/Trinket.app"
            other.mkdir(parents=True)
            fake = root / "bin"
            fake.mkdir()
            xcrun = fake / "xcrun"
            xcrun.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ["MIRROR_CALLS"], "a") as stream:
    stream.write(json.dumps(sys.argv[1:]) + "\\n")
if sys.argv[1:4] == ["simctl", "list", "devices"]:
    print(json.dumps({"devices": {"runtime": [
        {"name": "Trinket Run", "udid": "human", "state": "Booted"},
        {"name": "Trinket Agent 2", "udid": "peer", "state": "Booted"}]}}))
elif sys.argv[1:3] == ["simctl", "install"]:
    sys.exit(int(os.environ["INSTALL_STATUS"]))
else:
    sys.exit(92)
''')
            xcrun.chmod(0o755)
            env = {key: value for key, value in os.environ.items()
                   if not key.startswith("TRINKET_") and key not in {"DERIVED_DATA_PATH", "RESULTS_DIR", "GITHUB_ACTIONS"}}
            env.update(PATH=f"{fake}:{env['PATH']}", MIRROR_CALLS=str(calls))
            for build_status, install_status, product in ((0, 0, True), (65, 0, True), (0, 1, True), (0, 0, False)):
                with self.subTest(build=build_status, install=install_status, product=product):
                    if not product:
                        shutil.rmtree(app)
                    calls.write_text("")
                    result = subprocess.run([str(scripts / "promote.sh")], cwd=root,
                                            env={**env, "BUILD_STATUS": str(build_status), "INSTALL_STATUS": str(install_status)},
                                            capture_output=True, text=True, timeout=10)
                    self.assertEqual(result.returncode, 0 if build_status == install_status == 0 and product else 1,
                                     result.stdout + result.stderr)
                    lines = calls.read_text().splitlines()
                    self.assertEqual(lines.count("build"), 1)
                    commands = [json.loads(line) for line in lines if line != "build"]
                    installs = [command for command in commands if command[:2] == ["simctl", "install"]]
                    self.assertEqual(installs, [] if build_status or not product else [["simctl", "install", "human", str(app)]])
                    self.assertFalse(any(command[1] in {"terminate", "launch"} for command in commands))
                    self.assertFalse(list((root / ".DerivedData/.active-sim").glob("*.slot")))

    def test_format_roots_derived_from_packages(self) -> None:
        text = (ROOT / "Scripts" / "format-dirs.env").read_text()
        self.assertIn("TRINKET_TEST_PACKAGES", text)
        self.assertNotIn("Packages/TrinketCore/Tests", text)


if __name__ == "__main__":
    unittest.main()
