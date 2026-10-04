#!/usr/bin/env python3

from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/ci-diagnostics.sh',
    'Scripts/diagnostic_maintenance.py',
    'Scripts/config/infrastructure-patterns.env',
    'Scripts/config/simulator-names.env',
    'Scripts/ensure-simulator.sh',
    'Scripts/install-device.sh',
    'Scripts/lib/infrastructure-patterns.sh',
    'Scripts/lib/lock.sh',
    'Scripts/lib/promote.sh',
    'Scripts/lib/simctl.sh',
    'Scripts/lib/slots.sh',
    'Scripts/lib/xcode-manifest.sh',
    'Scripts/lib/xcode-watchdog.sh',
    'Scripts/lib/xcodebuild-infra.sh',
    'Scripts/playthrough-sweep.sh',
    'Scripts/playthrough_sweep.py',
    'Scripts/promote.sh',
    'Scripts/record-time-profiler.sh',
    'Scripts/release.sh',
    'Scripts/run-env.sh',
    'Scripts/run-simulator.sh',
    'Scripts/simctl_json.py',
    'Scripts/test-deploy.sh',
    'Scripts/validate-commit-msg.sh',
    'Scripts/xcode-runner.sh',
)


import json
import contextlib
import io
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

from script_test_support import ROOT, ScriptRegressionTestCase, load_script
from unittest.mock import patch

import plistlib
import pty
import shutil
import signal

class CISessionScriptTests(ScriptRegressionTestCase):
    def test_gate_artifact_keeps_failure_logs_with_size_bounds(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            results = root / 'TestResults'
            logs = results / 'script-tests.fixture'
            logs.mkdir(parents=True)
            (results / 'gate.log').write_text('gate failed\n')
            (logs / 'python-test.log').write_bytes(b'first error\n' + b'x' * (2 * 1024 * 1024) + b'\nlast error\n')
            (logs / 'docs.log').write_text('missing target\n')
            external = root / 'foreign.log'
            external.write_text('unrelated evidence')
            (logs / 'foreign.log').symlink_to(external)
            artifact = root / 'artifact'
            result = subprocess.run([str(ROOT / 'Scripts/ci-diagnostics.sh'), '--stage-gate-artifacts',
                                     str(results), str(artifact)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            retained = (artifact / 'script-tests.fixture/python-test.log').read_bytes()
            self.assertLessEqual(len(retained), 1024 * 1024)
            self.assertTrue(retained.startswith(b'first error'))
            self.assertTrue(retained.endswith(b'last error\n'))
            self.assertIn(b'diagnostic middle omitted', retained)
            self.assertEqual((artifact / 'script-tests.fixture/docs.log').read_text(), 'missing target\n')
            self.assertEqual((artifact / 'gate.log').read_text(), 'gate failed\n')
            self.assertFalse((artifact / 'script-tests.fixture/foreign.log').exists())
            self.assertGreater((logs / 'python-test.log').stat().st_size, len(retained))
            for index in range(20):
                (logs / f'z-large-{index:02}.log').write_bytes(b'x' * (1024 * 1024))
            repeated = subprocess.run([str(ROOT / 'Scripts/ci-diagnostics.sh'), '--stage-gate-artifacts',
                                      str(results), str(artifact)], capture_output=True, text=True)
            self.assertEqual(repeated.returncode, 0, repeated.stderr)
            files = [path for path in artifact.rglob('*') if path.is_file()]
            self.assertLessEqual(len(files), 128)
            self.assertLessEqual(sum(path.stat().st_size for path in files), 16 * 1024 * 1024)

    def test_ci_diagnostics_stages_structured_artifacts_and_failure_forensics(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results = Path(directory) / "TestResults"
            results.mkdir()
            raw = results / "raw"
            raw.mkdir(exist_ok=True)
            (raw / "pass.log").write_text("pass\n", encoding="utf-8")
            (results / "pass.xcresult").mkdir()
            (results / "pass-invocation.json").write_text(
                json.dumps(
                    {
                        "status": "passed",
                        "exit_code": 0,
                        "result_bundle": str(results / "pass.xcresult"),
                    }
                ),
                encoding="utf-8",
            )
            (results / "ci-diagnostics.json").write_text(
                json.dumps({"category": "passed"}), encoding="utf-8"
            )
            passed_stage = Path(directory) / "passed-artifact"
            staged = subprocess.run(
                [
                    str(ROOT / "Scripts" / "ci-diagnostics.sh"),
                    "--stage-artifacts",
                    str(results),
                    str(passed_stage),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(staged.returncode, 0, staged.stderr)
            self.assertFalse((passed_stage / "raw").exists())
            self.assertTrue((passed_stage / "ci-diagnostics.json").exists())

            raw.mkdir(exist_ok=True)
            (raw / "pass.log").write_text("failure evidence\n", encoding="utf-8")
            (results / "pass.xcresult").mkdir(exist_ok=True)
            (results / "ci-diagnostics.json").write_text(
                json.dumps({"category": "test-failure"}), encoding="utf-8"
            )
            failed_stage = Path(directory) / "failed-artifact"
            staged = subprocess.run(
                [
                    str(ROOT / "Scripts" / "ci-diagnostics.sh"),
                    "--stage-artifacts",
                    str(results),
                    str(failed_stage),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(staged.returncode, 0, staged.stderr)
            self.assertTrue((failed_stage / "raw" / "pass.log").exists())

    def test_ci_diagnostics_rejects_overlapping_artifact_destinations(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            results = root / "run" / "TestResults"
            results.mkdir(parents=True)
            evidence = results / "raw" / "failure.log"
            evidence.parent.mkdir()
            evidence.write_text("failure evidence\n")
            alias = root / "alias"
            alias.symlink_to(results.parent, target_is_directory=True)
            for destination in (results.parent, alias, results / "raw" / "artifact"):
                with self.subTest(destination=destination):
                    evidence.parent.mkdir(parents=True, exist_ok=True)
                    evidence.write_text("failure evidence\n")
                    result = subprocess.run(
                        [str(ROOT / "Scripts/ci-diagnostics.sh"), "--stage-artifacts", str(results), str(destination)],
                        cwd=ROOT, capture_output=True, text=True,
                    )
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(evidence.read_text(), "failure evidence\n")

    def test_ci_diagnostics_selects_session_and_cleans_passed_history(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results = Path(directory) / "TestResults"
            results.mkdir()
            for label, session, status, exit_code in (
                ("old", "session-old", "passed", 0),
                ("current", "session-current", "failed", 65),
            ):
                (results / f"{label}-invocation.json").write_text(
                    json.dumps(
                        {
                            "label": label,
                            "session_id": session,
                            "status": status,
                            "exit_code": exit_code,
                            "result_bundle": str(results / f"{label}.xcresult"),
                            "generated_at": f"2026-08-20T00:00:0{len(label)}Z",
                        }
                    ),
                    encoding="utf-8",
                )
            aggregate = results / "current.json"
            selected = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "ci-diagnostics.py"), str(results), str(aggregate)],
                cwd=ROOT,
                env={**os.environ, "TRINKET_DIAGNOSTICS_SESSION_ID": "session-current"},
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(selected.returncode, 0, selected.stderr)
            payload = json.loads(aggregate.read_text(encoding="utf-8"))
            self.assertEqual(payload["recorded_invocations"], 1)
            self.assertEqual(payload["session_id"], "session-current")

            passed_bundle = results / "passed.xcresult"
            passed_bundle.mkdir()
            raw = results / "raw"
            raw.mkdir()
            (raw / "passed.log").write_text("pass\n", encoding="utf-8")
            (results / "passed-invocation.json").write_text(
                json.dumps(
                    {
                        "status": "passed",
                        "exit_code": 0,
                        "result_bundle": str(passed_bundle),
                    }
                ),
                encoding="utf-8",
            )
            cleaned = subprocess.run(
                [str(ROOT / "Scripts" / "ci-diagnostics.sh"), "--cleanup", str(results)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(cleaned.returncode, 0, cleaned.stderr)
            self.assertFalse(passed_bundle.exists())
            self.assertFalse((raw / "passed.log").exists())
            self.assertTrue((results / "current-invocation.json").exists())

            kept_bundle = results / "kept.xcresult"
            kept_bundle.mkdir()
            (results / "kept-invocation.json").write_text(
                json.dumps(
                    {
                        "status": "passed",
                        "exit_code": 0,
                        "result_bundle": str(kept_bundle),
                    }
                ),
                encoding="utf-8",
            )
            kept = subprocess.run(
                [str(ROOT / "Scripts" / "ci-diagnostics.sh"), "--cleanup", "--keep", str(results)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(kept.returncode, 0, kept.stderr)
            self.assertTrue(kept_bundle.exists())

    def test_cleanup_rejects_results_root_and_escaping_artifact_paths(self) -> None:
        maintenance = load_script("diagnostic_cleanup", "diagnostic_maintenance.py")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            results = root / "TestResults"
            results.mkdir()
            evidence = results / "failed.xcresult"
            evidence.mkdir()
            (evidence / "failure.txt").write_text("keep failure evidence")
            outside = root / "outside"
            outside.mkdir()
            (outside / "keep.txt").write_text("keep outside evidence")
            alias = results / "alias"
            alias.symlink_to(outside, target_is_directory=True)
            for artifact in (results, outside, alias):
                with self.subTest(artifact=artifact):
                    (results / "passed-invocation.json").write_text(json.dumps({
                        "status": "passed", "exit_code": 0,
                        "result_bundle": str(artifact), "diagnostics_json": str(artifact),
                    }))
                    with patch.dict(os.environ, TRINKET_ORPHAN_MAX_AGE_DAYS="-1"), contextlib.redirect_stdout(io.StringIO()):
                        maintenance.cleanup(results, keep=False)
                    self.assertEqual((evidence / "failure.txt").read_text(), "keep failure evidence")
                    self.assertEqual((outside / "keep.txt").read_text(), "keep outside evidence")
            (results / "malformed-invocation.json").write_text("[]")
            with patch.dict(os.environ, TRINKET_ORPHAN_MAX_AGE_DAYS="-1"), contextlib.redirect_stdout(io.StringIO()):
                maintenance.cleanup(results, keep=False)
            self.assertEqual((evidence / "failure.txt").read_text(), "keep failure evidence")

    def test_unreadable_category_keeps_forensics_and_reset_unlinks_attachment_aliases(self) -> None:
        maintenance = load_script('diagnostic_retention', 'diagnostic_maintenance.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            results = root / 'TestResults'
            (results / 'raw').mkdir(parents=True)
            (results / 'raw/failure.log').write_text('failure evidence')
            (results / 'ci-diagnostics.json').write_text('[]')
            external = root / 'external'
            external.mkdir()
            (external / 'keep.txt').write_text('foreign evidence')
            with contextlib.redirect_stdout(io.StringIO()):
                maintenance.stage(results, root / 'artifact')
                (results / 'run-diagnostics.attachments').symlink_to(external)
                maintenance.reset(results)
            self.assertEqual((root / 'artifact/raw/failure.log').read_text(), 'failure evidence')
            self.assertFalse((results / 'run-diagnostics.attachments').is_symlink())
            self.assertEqual((external / 'keep.txt').read_text(), 'foreign evidence')

    def test_cleanup_retains_evidence_when_exit_code_is_not_an_integer(self) -> None:
        maintenance = load_script("diagnostic_cleanup_exit_codes", "diagnostic_maintenance.py")
        with tempfile.TemporaryDirectory() as directory:
            results = (Path(directory) / "TestResults").resolve()
            results.mkdir()
            bundle = results / "build.xcresult"
            bundle.mkdir()
            evidence = bundle / "failure.txt"
            evidence.write_text("keep failure evidence")
            manifest = results / "build-invocation.json"
            for code in (False, 0.0, "0", None):
                with self.subTest(exit_code=code):
                    manifest.write_text(json.dumps({
                        "status": "passed", "exit_code": code, "result_bundle": str(bundle),
                    }))
                    with patch.dict(os.environ, TRINKET_ORPHAN_MAX_AGE_DAYS="-1"), contextlib.redirect_stdout(io.StringIO()):
                        maintenance.cleanup(results, keep=False)
                    self.assertEqual(evidence.read_text(), "keep failure evidence")
                    self.assertTrue(manifest.exists())
            manifest.write_text(json.dumps({"status": "passed", "exit_code": 0, "result_bundle": str(bundle)}))
            with contextlib.redirect_stdout(io.StringIO()):
                maintenance.cleanup(results, keep=False)
            self.assertFalse(bundle.exists())
            self.assertFalse(manifest.exists())

    def test_ci_diagnostics_warns_when_sessions_share_a_results_dir(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results = Path(directory) / "TestResults"
            results.mkdir()
            for label, session, seconds in (("older", "session-a", "00"), ("newer", "session-b", "30")):
                (results / f"{label}-invocation.json").write_text(
                    json.dumps(
                        {
                            "label": label,
                            "session_id": session,
                            "status": "passed",
                            "exit_code": 0,
                            "result_bundle": "",
                            "generated_at": f"2026-08-20T00:00:{seconds}Z",
                        }
                    ),
                    encoding="utf-8",
                )
            aggregate = results / "current.json"
            env = {**os.environ}
            env.pop("TRINKET_DIAGNOSTICS_SESSION_ID", None)
            unscoped = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "ci-diagnostics.py"), str(results), str(aggregate)],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(unscoped.returncode, 0, unscoped.stderr)
            payload = json.loads(aggregate.read_text(encoding="utf-8"))
            self.assertEqual(payload["distinct_sessions"], 2)
            self.assertIn("Warning:", payload["detail"])
            self.assertIn("--reset", payload["session_warning"])

    def test_shared_runs_receive_distinct_sessions_and_nested_retains_parent(self) -> None:
        run_env = ROOT / "Scripts" / "run-env.sh"
        self.assertIn(
            "trinket_run_env_ensure_diagnostics_session",
            run_env.read_text(encoding="utf-8"),
        )

        def init_session(extra_env: dict[str, str]) -> str:
            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1" && unset TRINKET_ISOLATE TRINKET_RUN_ID TRINKET_DIAGNOSTICS_SESSION_ID '
                    "DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT && "
                    "trinket_run_env_init >/dev/null && printf '%s' \"$TRINKET_DIAGNOSTICS_SESSION_ID\"",
                    "_",
                    str(run_env),
                ],
                cwd=ROOT,
                env={**os.environ, **extra_env},
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            session = result.stdout.strip()
            self.assertTrue(session)
            return session

        first = init_session({})
        second = init_session({})
        self.assertNotEqual(first, second)

        nested = subprocess.run(
            [
                "bash",
                "-c",
                'source "$1" && unset TRINKET_ISOLATE TRINKET_RUN_ID DERIVED_DATA_PATH RESULTS_DIR '
                'TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT && '
                'export TRINKET_DIAGNOSTICS_SESSION_ID="parent-session" && '
                "trinket_run_env_init >/dev/null && printf '%s' \"$TRINKET_DIAGNOSTICS_SESSION_ID\"",
                "_",
                str(run_env),
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(nested.returncode, 0, nested.stderr)
        self.assertEqual(nested.stdout.strip(), "parent-session")

    def test_aggregation_selects_newest_failed_while_retaining_old(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results = Path(directory) / "TestResults"
            results.mkdir()
            for label, session, seconds in (
                ("old-fail", "session-old-fail", "00"),
                ("new-fail", "session-new-fail", "30"),
            ):
                (results / f"{label}-invocation.json").write_text(
                    json.dumps(
                        {
                            "label": label,
                            "session_id": session,
                            "status": "failed",
                            "exit_code": 65,
                            "result_bundle": "",
                            "generated_at": f"2026-08-20T00:00:{seconds}Z",
                        }
                    ),
                    encoding="utf-8",
                )
            aggregate = results / "current.json"
            env = {**os.environ}
            env.pop("TRINKET_DIAGNOSTICS_SESSION_ID", None)
            unscoped = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "ci-diagnostics.py"), str(results), str(aggregate)],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(unscoped.returncode, 0, unscoped.stderr)
            payload = json.loads(aggregate.read_text(encoding="utf-8"))
            self.assertEqual(payload["session_id"], "session-new-fail")
            self.assertEqual(payload["recorded_invocations"], 1)
            self.assertEqual(payload["failed_invocations"], 1)
            # Old retained failures remain available for forensic use.
            self.assertTrue((results / "old-fail-invocation.json").exists())
            self.assertTrue((results / "new-fail-invocation.json").exists())

    def test_cleanup_sweeps_orphan_bundles_and_logs_by_age(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results = Path(directory) / "TestResults"
            raw = results / "raw"
            raw.mkdir(parents=True)
            stale_time = time.time() - 10 * 86400

            orphan_bundle = results / "crashed-run.xcresult"
            orphan_bundle.mkdir()
            orphan_log = raw / "crashed-run.log"
            orphan_log.write_text("partial output\n", encoding="utf-8")
            fresh_log = raw / "fresh-run.log"
            fresh_log.write_text("recent\n", encoding="utf-8")
            claimed_log = raw / "claimed-run.log"
            claimed_log.write_text("has diagnostics report\n", encoding="utf-8")
            (results / "claimed-run-diagnostics.json").write_text("{}", encoding="utf-8")
            for path in (orphan_bundle, orphan_log):
                os.utime(path, (stale_time, stale_time))

            cleaned = subprocess.run(
                [str(ROOT / "Scripts" / "ci-diagnostics.sh"), "--cleanup", str(results)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(cleaned.returncode, 0, cleaned.stderr)
            self.assertFalse(orphan_bundle.exists())
            self.assertFalse(orphan_log.exists())
            # Fresh orphans and evidence with a diagnostics report survive.
            self.assertTrue(fresh_log.exists())
            self.assertTrue(claimed_log.exists())


    def test_simulator_launcher_installs_resolved_product_and_rejects_missing_outputs(self) -> None:
        for mode in ("valid", "missing-target", "missing-product", "missing-plist", "settings-failed",
                     "inspect-stop", "inspect-eof", "inspect-cancel", "inspect-no-terminal", "inspect-legacy"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                scripts = root / "Scripts"
                shutil.copytree(ROOT / "Scripts", scripts)
                (scripts / "lib/tools.sh").write_text('trinket_prepend_pinned_tools() { :; }\n')
                if not mode.startswith("inspect-"):
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
    if not pathlib.Path('mode').read_text().startswith('inspect-'):
        raise SystemExit(73)
if 'appearance' in sys.argv:
    print('dark')
""",
                }
                if mode.startswith("inspect-"):
                    developer = root / "Xcode.app/Contents/Developer"
                    device_app = (developer / "Applications/Simulator.app" if mode == "inspect-legacy"
                                  else developer.parent / "Applications/DeviceHub.app")
                    device_app.mkdir(parents=True)
                    commands["xcode-select"] = "#!/bin/sh\nprintf '%s\\n' '" + str(developer) + "'\n"
                    commands["open"] = """#!/usr/bin/env python3
import json, pathlib, sys
pathlib.Path('open.json').write_text(json.dumps(sys.argv[1:]))
"""
                for name, source in commands.items():
                    binary = binaries / name
                    binary.write_text(source)
                    binary.chmod(0o755)
                environment = {key: value for key, value in os.environ.items()
                               if not key.startswith("TRINKET_") and key not in {"DERIVED_DATA_PATH", "RESULTS_DIR"}}
                environment["PATH"] = str(binaries) + os.pathsep + os.environ["PATH"]
                if mode.startswith("inspect-"):
                    environment.pop("DEVELOPER_DIR", None)
                    command = [str(scripts / "run-simulator.sh"), "--isolate", "--inspect"]
                    if mode == "inspect-no-terminal":
                        result = subprocess.run(command, env=environment, stdin=subprocess.DEVNULL,
                                                capture_output=True, text=True)
                        self.assertEqual(result.returncode, 1, result.stderr)
                        self.assertFalse((root / ".DerivedData").exists())
                        self.assertFalse((root / "build-args.jsonl").exists())
                        continue
                    master, slave = pty.openpty()
                    try:
                        with (root / "inspection.log").open("w+") as output:
                            process = subprocess.Popen(command, env=environment, stdin=slave,
                                                       stdout=output, stderr=output)
                            try:
                                deadline = time.monotonic() + 15
                                while time.monotonic() < deadline:
                                    output.seek(0)
                                    transcript = output.read()
                                    if "Inspection ready:" in transcript or process.poll() is not None:
                                        break
                                    time.sleep(0.02)
                                self.assertIn("Inspection ready:", transcript)
                                self.assertIn("Trinket Agent 1 (fixture)", transcript)
                                self.assertIn(str(app), transcript)
                                self.assertIsNone(process.poll())
                                lease = root / ".DerivedData/.active-sim/1.slot"
                                self.assertTrue(lease.exists())
                                if mode == "inspect-cancel":
                                    process.send_signal(signal.SIGTERM)
                                else:
                                    os.write(master, b"stop\n" if mode == "inspect-stop" else b"\x04")
                                self.assertEqual(process.wait(timeout=10), 143 if mode == "inspect-cancel" else 0)
                                self.assertFalse(lease.exists())
                            finally:
                                if process.poll() is None:
                                    process.kill()
                                    process.wait(timeout=5)
                    finally:
                        os.close(master)
                        os.close(slave)
                    self.assertEqual(json.loads((root / "install.json").read_text()), ["fixture", str(app)])
                    opened = json.loads((root / "open.json").read_text())
                    self.assertEqual(opened[:2], ["-a", str(device_app)])
                    self.assertEqual(opened[2:], ["--args", "-CurrentDeviceUDID", "fixture"]
                                     if mode == "inspect-legacy" else [])
                    continue
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


    def test_simulator_queries_select_managed_devices_and_tolerate_malformed_containers(self) -> None:
        query = load_script("simctl_queries", "simctl_json.py")
        data = {"devices": {"runtime": [
            {"name": "Trinket Run", "udid": "shared", "state": "Booted"},
            {"name": "Trinket Agent 1", "udid": "agent", "state": "Booted"},
            {"name": "Other phone", "udid": "foreign", "state": "Booted"},
            {"name": "Trinket CI", "udid": "asleep", "state": "Shutdown"}, None,
        ]}}
        cases = [
            (["udid-for-name", "Trinket Agent 1"], data, 0, "agent\n"),
            (["name-for-udid", "shared"], data, 0, "Trinket Run\n"),
            (["state-for-udid", "asleep"], data, 0, "Shutdown\n"),
            (["booted-managed"], data, 0, "shared\tTrinket Run\nagent\tTrinket Agent 1\n"),
            (["preview-count"], data, 0, "4\t3\n"),
            (["udid-for-name", "missing"], data, 1, ""),
            (["count-booted"], {"devices": None}, 0, "0\n"),
            (["booted-managed"], {"devices": []}, 0, ""),
        ]
        for args, payload, status, expected in cases:
            with self.subTest(args=args, payload=payload), patch.object(query, "payload", return_value=payload):
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    self.assertEqual(query.main(args), status)
                self.assertEqual(output.getvalue(), expected)


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
        def check(case: tuple[str, signal.Signals]) -> None:
            owner, sig = case
            with tempfile.TemporaryDirectory() as directory:
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
if [[ "$1" == run-env ]]; then
  SIMULATOR_UDID=fixture
  guest_pid="$3"
  # ps is called without the fixture arguments, so retain the detached PID.
  ps() {
    echo "100 1 Wed Sep 30 12:00:00 2026 launchd_sim /Devices/fixture/data/var/run/launchd_bootstrap.plist"
    if [[ "${guest_started:-0}" == 1 ]]; then
      echo "$guest_pid 100 Wed Sep 30 12:01:00 2026 /Xcode/Agents/xctest"
    fi
  }
  trinket_track_test_guests
  guest_started=1
fi
bash -c 'trap "" INT TERM; printf ready > "$1/worker-ready"; while :; do sleep 1; done' _ "$2" &
worker=$!
while [[ ! -e "$2/worker-ready" ]]; do sleep 0.01; done
printf '%s %s\\n' "$resource" "$worker"
wait "$worker"
echo continued > "$2/continued"
'''
                env = {key: value for key, value in os.environ.items()
                       if not key.startswith("TRINKET_") and key not in {"DERIVED_DATA_PATH", "RESULTS_DIR"}}
                guest = subprocess.Popen(["sleep", "60"])
                self.addCleanup(lambda: guest.wait(timeout=5))
                self.addCleanup(lambda: guest.poll() is None and guest.kill())
                process = subprocess.Popen(["bash", "-eu", "-c", script, "_", owner, directory, str(guest.pid)],
                                           cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                resource_path, worker_pid = process.stdout.readline().split()
                resource = Path(resource_path)
                self.assertTrue(resource.exists())
                os.kill(int(worker_pid), 0)
                process.send_signal(sig)
                stdout, stderr = process.communicate(timeout=10)
                self.assertEqual(process.returncode, 128 + sig, stdout + stderr)
                self.assertFalse(resource.exists())
                self.assertFalse((Path(directory) / "continued").exists())
                if owner == "run-env":
                    self.assertEqual(guest.wait(timeout=5), -signal.SIGKILL)
                    self.assertFalse(Path(str(resource) + ".guest-tests").exists())
                with self.assertRaises(ProcessLookupError):
                    os.kill(int(worker_pid), 0)


        cases = [(owner, sig) for owner in ("lock", "run-env") for sig in (signal.SIGINT, signal.SIGTERM)]
        # Each process owns a separate fixture root and lease; only fake workers
        # run concurrently. Readiness comes from the child after installing its
        # signal traps and the parent stores its PID, so cancellation cannot
        # interrupt the fixture before its EXIT assertion has a worker to inspect.
        with ThreadPoolExecutor(max_workers=len(cases)) as executor:
            futures = [executor.submit(check, case) for case in cases]
            for case, future in zip(cases, futures):
                with self.subTest(owner=case[0], signal=case[1]):
                    future.result()

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



if __name__ == "__main__":
    unittest.main()
