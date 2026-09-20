#!/usr/bin/env python3
"""Build contracts exercised without invoking Xcode or reserving simulators."""

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
    'Scripts/config/generated-paths.tsv',
    'Scripts/config/simulator-names.env',
    'Scripts/config/ui-tests.tsv',
    'Scripts/ensure-ci-tools.sh',
    'Scripts/ensure-git-cliff.sh',
    'Scripts/ensure-simulator.sh',
    'Scripts/format-dirs.env',
    'Scripts/format.sh',
    'Scripts/generate.sh',
    'Scripts/lib/app-build.sh',
    'Scripts/lib/args.sh',
    'Scripts/lib/ci-tools.d/ripgrep.sh',
    'Scripts/lib/ci-tools.d/xcodegen.sh',
    'Scripts/lib/derived-data.sh',
    'Scripts/lib/generated-paths.sh',
    'Scripts/lib/lock.sh',
    'Scripts/lib/project-generation.sh',
    'Scripts/lib/simctl.sh',
    'Scripts/lib/slots.sh',
    'Scripts/lib/tempdir.sh',
    'Scripts/lib/test-helpers.sh',
    'Scripts/lib/test-style.sh',
    'Scripts/lib/tool-install.sh',
    'Scripts/lib/tools.sh',
    'Scripts/lint-analyze.sh',
    'Scripts/lint.sh',
    'Scripts/prune-derived-data-cache.sh',
    'Scripts/run-env.sh',
    'Scripts/simctl_json.py',
    'Scripts/stage-ci-test-artifact.sh',
    'Scripts/test-package.sh',
    'Scripts/test.sh',
    'Scripts/tool-versions.env',
    'Scripts/update-tools.sh',
)


import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BuildProcessTests(unittest.TestCase):
    def test_architecture_selection_preserves_ci_release_and_device_defaults(self):
        for host in ("arm64", "x86_64"):
            for sdk, configuration, ci, github, narrowed in (
                ("iphonesimulator", "Debug", "", "", True),
                ("iphonesimulator", "Debug", "false", "false", True),
                ("iphonesimulator", "Debug", "true", "", False),
                ("iphonesimulator", "Debug", "", "true", False),
                ("iphonesimulator", "Release", "", "", False),
                ("iphoneos", "Debug", "", "", False),
                ("iphoneos", "Release", "", "", False),
            ):
                with self.subTest(host=host, sdk=sdk, configuration=configuration, ci=ci, github=github):
                    result = subprocess.run(
                        ["bash", "-eu", "-c", '''
source Scripts/lib/app-build.sh
uname() { printf '%s\\n' "$TEST_HOST_ARCH"; }
trinket_set_app_xcodebuild_args /tmp/build "$1" generic "$2"
printf '%s\\n' "${TRINKET_APP_XCODEBUILD_ARGS[@]}"
''', "_", sdk, configuration], cwd=ROOT, capture_output=True, text=True,
                        env={**os.environ, "CI": ci, "GITHUB_ACTIONS": github, "TEST_HOST_ARCH": host},
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    args = result.stdout.splitlines()
                    self.assertEqual([arg for arg in args if arg.startswith("ARCHS=")],
                                     [f"ARCHS={host}"] if narrowed else [])
                    self.assertEqual(args[args.index("-configuration") + 1], configuration)
                    if sdk == "iphonesimulator":
                        self.assertIn("CODE_SIGNING_ALLOWED=YES", args)
                        self.assertIn("CODE_SIGN_IDENTITY=-", args)

    def test_app_and_package_test_builds_share_local_architecture_policy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = self.fixture(root)
            (scripts / "build-freshness.sh").write_text(
                (ROOT / "Scripts/build-freshness.sh").read_text()
                + '\nprepare_generated_inputs() { :; }\ntouch_build_stamp() { :; }\n'
            )
            (scripts / "ensure-simulator.sh").write_text('trinket_sim_slot_ensure() { :; }\n')
            for entrypoint, flags in (
                ("build-for-testing.sh", ["--app-only"]),
                ("test-package.sh", ["--build-for-testing", "TrinketCore"]),
            ):
                for ci in ("", "true"):
                    with self.subTest(entrypoint=entrypoint, ci=ci):
                        result = subprocess.run(
                            [str(scripts / entrypoint), *flags], capture_output=True, text=True,
                            env={**os.environ, "CI": ci, "GITHUB_ACTIONS": ""},
                        )
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                        args = (root / "arguments").read_text().splitlines()
                        self.assertEqual(args[:2], ["xcodebuild", "build-for-testing"])
                        self.assertEqual(args[args.index("-configuration") + 1], "Debug")
                        self.assertEqual([arg for arg in args if arg.startswith("ARCHS=")],
                                         [] if ci else [f"ARCHS={os.uname().machine}"])

    def fixture(self, root):
        scripts = root / "Scripts"
        shutil.copytree(ROOT / "Scripts", scripts)
        (scripts / "run-env.sh").write_text(
            'trinket_run_env_init() { DERIVED_DATA_PATH="$PWD/dd"; RESULTS_DIR="$PWD/results"; '
            'mkdir -p "$DERIVED_DATA_PATH" "$RESULTS_DIR"; }\n'
            'trinket_run_env_print() { :; }\n'
        )
        (scripts / "build-freshness.sh").write_text(
            'prepare_generated_inputs() { :; }\n'
            'touch_build_stamp() { echo unexpected-stamp; exit 91; }\n'
        )
        (scripts / "xcode-runner.sh").write_text(
            'xcode_runner_prepare() { XCODE_RUNNER_INVOCATION_ID=fixture; XCODE_RUNNER_LOG_PATH="$PWD/compiler.log"; '
            'XCODE_RUNNER_REPORT_PREFIX="$PWD/report"; XCODE_RUNNER_RESULT_BUNDLE_PATH="$PWD/result.xcresult"; }\n'
            'xcode_runner_run() { while [[ "$1" != -- ]]; do shift; done; shift; '
            'printf "%s\\n" "$@" > "$PWD/arguments"; echo swiftc > "$PWD/compiler.log"; '
            'return "${BUILD_STATUS:-0}"; }\n'
        )
        return scripts

    def test_compile_actions_do_not_stamp_test_products(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = self.fixture(root)
            for flags, sdk, destination in (
                ([], "iphonesimulator", "generic/platform=iOS Simulator"),
                (["--release-device"], "iphoneos", "generic/platform=iOS"),
            ):
                with self.subTest(flags=flags):
                    result = subprocess.run([str(scripts / "build.sh"), *flags], capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    args = (root / "arguments").read_text().splitlines()
                    self.assertEqual(args[:2], ["xcodebuild", "build"])
                    self.assertEqual(args[args.index("-sdk") + 1], sdk)
                    self.assertEqual(args[args.index("-destination") + 1], destination)
                    derived = args[args.index("-derivedDataPath") + 1]
                    self.assertIn(f"SYMROOT={derived}/Build/Products", args)
                    self.assertIn(f"OBJROOT={derived}/Build/Intermediates.noindex", args)
                    if flags:
                        self.assertIn("Release", args)
                        self.assertIn("CODE_SIGNING_ALLOWED=NO", args)
            result = subprocess.run([str(scripts / "build.sh")], env={**os.environ, "BUILD_STATUS": "65"}, capture_output=True)
            self.assertEqual(result.returncode, 65)

    def test_ui_reuse_and_device_install_share_the_build_product_roots(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = self.fixture(root)
            with (scripts / "run-env.sh").open("a") as stream:
                stream.write('trinket_run_env_install_self_clean() { :; }\ntrinket_ui_slot_acquire() { :; }\n')
            with (scripts / "build-freshness.sh").open("a") as stream:
                stream.write('build_stamp_path() { echo "$PWD/prior.stamp"; }\n')
            (scripts / "ensure-simulator.sh").write_text(
                'trinket_sim_slot_ensure() { :; }\n'
                'ensure_test_simulator_logged() { SIMULATOR_DESTINATION=id=fixture; }\n'
            )
            (scripts / "lib/test-helpers.sh").write_text(
                'trinket_assert_no_build_is_fresh() { :; }\n'
                'trinket_assert_targeted_tests_executed() { :; }\ntrinket_record_timing() { :; }\n'
            )
            env = {**os.environ, "TRINKET_ISOLATE": "1", "PATH": f"{root}:{os.environ['PATH']}"}
            result = subprocess.run([str(scripts / "test.sh"), "smoke", "--no-build", "SmokeShellTests"],
                                    env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            args = (root / "arguments").read_text().splitlines()
            self.assertEqual(args[:2], ["xcodebuild", "test-without-building"])
            self.assertEqual(args.count("-destination"), 1)
            self.assertIn("id=fixture", args)
            self.assertIn(f"SYMROOT={root}/dd/Build/Products", args)
            self.assertIn(f"OBJROOT={root}/dd/Build/Intermediates.noindex", args)
            for name, body in (
                ("xcodebuild", 'printf "%s\\n" "$@" > arguments\n'
                 'for arg in "$@"; do if [[ "$arg" == SYMROOT=* ]]; then mkdir -p "${arg#SYMROOT=}/Debug-iphoneos/Trinket.app"; fi; done\n'),
                ("xcrun", 'printf "%s\\n" "$@" > installed\n'),
            ):
                binary = root / name
                binary.write_text('#!/bin/bash\n' + body)
                binary.chmod(0o755)
            result = subprocess.run([str(scripts / "install-device.sh"), "--device", "fixture", "--no-launch"],
                                    env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            args = (root / "arguments").read_text().splitlines()
            products = f"{root}/.DerivedData/Device/Build/Products"
            self.assertIn(f"SYMROOT={products}", args)
            self.assertIn("-allowProvisioningUpdates", args)
            self.assertNotIn("CODE_SIGNING_ALLOWED=NO", args)
            self.assertIn(f"{products}/Debug-iphoneos/Trinket.app", (root / "installed").read_text())

    def test_analyzer_requires_coverage_and_propagates_build_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = self.fixture(root)
            (scripts / "lib/tools.sh").write_text(
                'trinket_prepend_pinned_tools() { :; }\ntrinket_require_pinned_version() { :; }\n'
            )
            binary = root / "swiftlint"
            binary.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "$ANALYZE_ARGUMENTS"\necho "$ANALYZE_OUTPUT"\nexit "${ANALYZE_STATUS:-0}"\n')
            binary.chmod(0o755)
            (root / "Probe.swift").write_text("let answer = 42\n")
            cases = (
                ("Done analyzing! Found 0 violations, 0 serious in 0 files.", "0", "0", 1),
                ("Done analyzing! Found 0 violations, 0 serious in 1 file.", "0", "0", 0),
                ("unused_import\nDone analyzing! Found 1 violation in 1 file.", "1", "0", 1),
                ("Done analyzing! Found 0 violations in 1 file.", "0", "65", 65),
                ("Done analyzing! Found 0 violations in 1 file.", "2", "0", 2),
            )
            for output, status, build_status, expected in cases:
                with self.subTest(output=output, build_status=build_status, status=status):
                    env = {**os.environ, "PATH": f"{root}:{os.environ['PATH']}",
                           "ANALYZE_OUTPUT": output, "ANALYZE_STATUS": status, "BUILD_STATUS": build_status,
                           "ANALYZE_ARGUMENTS": str(root / "analyze-arguments")}
                    result = subprocess.run([str(scripts / "lint-analyze.sh"), "Probe.swift"], env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                    args = (root / "arguments").read_text().splitlines()
                    self.assertIn("analyze.", args[args.index("-derivedDataPath") + 1])
                    if build_status == "0":
                        self.assertIn(str((root / "Probe.swift").resolve()), (root / "analyze-arguments").read_text().splitlines())

    def test_failed_generation_does_not_mark_new_inputs_fresh(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Scripts").mkdir()
            for name in ("build-freshness.sh", "build-inputs.env"):
                shutil.copy2(ROOT / "Scripts" / name, root / "Scripts" / name)
            generator = root / "Scripts/generate.sh"
            generator.write_text('#!/bin/bash\nexit "${GENERATION_STATUS:-0}"\n')
            generator.chmod(0o755)
            command = """
source Scripts/build-freshness.sh
content_generation_inputs=(input); project_generation_inputs=(project); asset_generation_inputs=(asset)
touch input project asset
prepare_generated_inputs results
cp results/.last-generate.stamp.content previous
printf changed > input
export GENERATION_STATUS=7
status=0
prepare_generated_inputs results || status=$?
[[ $status -eq 7 ]]
cmp previous results/.last-generate.stamp.content
export GENERATION_STATUS=0
prepare_generated_inputs results
! cmp -s previous results/.last-generate.stamp.content
"""
            result = subprocess.run(["bash", "-eu", "-c", command], cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


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
                ("generate.sh", ["--force-xcodegen"], 1, "Unknown argument"),
                ("generate.sh", ["--bad-option"], 1, "Unknown argument"),
                ("test.sh", ["style"], 0, "style checked"),
                ("build-for-testing.sh", ["--bad-option"], 1, "Unknown argument"),
                ("test-package.sh", ["--bad-option"], 1, "Unknown argument"),
                ("test-package.sh", ["MissingPackage"], 1, "Unknown package"),
                ("test-package.sh", ["BattleEngine", "BattleEngine"], 1, "Duplicate package"),
                ("test-package.sh", ["--destination", "platform=macOS", "BattleEngine"], 1, "only platform=iOS Simulator"),
                ("test-package.sh", ["--destination", "generic/platform=macOS", "BattleEngine"], 1, "only platform=iOS Simulator"),
                ("test-package.sh", ["--destination", "", "BattleEngine"], 1, "requires a value"),
                ("test-package.sh", ["--destination", "platform=iOS,name=Phone", "BattleEngine"], 1, "only platform=iOS Simulator"),
                ("test-package.sh", ["--build-for-testing", "--destination", "id=fixture", "BattleEngine"], 1, "cannot be combined"),
                ("test-package.sh", ["--iterations", "0", "BattleEngine"], 1, "--iterations requires a positive integer"),
                ("test-package.sh", ["--iterations", "abc", "BattleEngine"], 1, "--iterations requires a positive integer"),
                ("test-package.sh", ["--build-for-testing", "--iterations", "2", "BattleEngine"], 1, "Repetition options cannot be combined"),
                ("test-package.sh", ["--build-for-testing", "--run-tests-until-failure", "BattleEngine"], 1, "Repetition options cannot be combined"),
            ]
            for name, args, status, message in cases:
                with self.subTest(name=name, args=args):
                    result = subprocess.run([str(scripts / name), *args], capture_output=True, text=True)
                    self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                    self.assertIn(message, result.stdout + result.stderr)



if __name__ == "__main__":
    unittest.main()
