#!/usr/bin/env python3
"""Build contracts exercised without invoking Xcode or reserving simulators."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from script_test_support import fake_toolchain, run_captured, write_executable

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
                    result = run_captured(["bash", "-eu", "-c", '''
source Scripts/lib/app-build.sh
uname() { printf '%s\\n' "$TEST_HOST_ARCH"; }
trinket_set_app_xcodebuild_args /tmp/build "$1" generic "$2"
printf '%s\\n' "${TRINKET_APP_XCODEBUILD_ARGS[@]}"
''', "_", sdk, configuration], cwd=ROOT, env={**os.environ, "CI": ci, "GITHUB_ACTIONS": github, "TEST_HOST_ARCH": host}, expected=0)
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
                + '\nprepare_generated_inputs() { :; }\nbegin_build_stamps() { :; }\ntouch_build_stamp() { :; }\n'
            )
            (scripts / "ensure-simulator.sh").write_text('trinket_sim_slot_ensure() { :; }\n')
            for entrypoint, flags in (
                ("build-for-testing.sh", ["--app-only"]),
                ("test-package.sh", ["--build-for-testing", "TrinketCore"]),
            ):
                for ci in ("", "true"):
                    with self.subTest(entrypoint=entrypoint, ci=ci):
                        run_captured([str(scripts / entrypoint), *flags], env={**os.environ, "CI": ci, "GITHUB_ACTIONS": "", "TRINKET_ALLOW_HEAVY_LOCAL": "1"}, expected=0)
                        args = (root / "arguments").read_text().splitlines()
                        if entrypoint == "test-package.sh":
                            tenant = args[args.index("-derivedDataPath") + 1]
                            self.assertEqual(tenant, str(root / "dd/packages/TrinketCore"))
                            self.assertIn(f"SYMROOT={tenant}/Build/Products", args)
                            self.assertIn(f"OBJROOT={tenant}/Build/Intermediates.noindex", args)
                            self.assertIn("-parallelizeTargets", args)
                            self.assertIn("-disableAutomaticPackageResolution", args)
                        self.assertEqual(args[:2], ["xcodebuild", "build-for-testing"])
                        self.assertEqual(args[args.index("-configuration") + 1], "Debug")
                        self.assertEqual([arg for arg in args if arg.startswith("ARCHS=")],
                                         [] if ci else [f"ARCHS={os.uname().machine}"])

    def fixture(self, root):
        scripts = root / "Scripts"
        shutil.copytree(ROOT / "Scripts", scripts)
        (scripts / "run-env.sh").write_text(
            'source Scripts/lib/args.sh\ntrinket_run_env_init() { DERIVED_DATA_PATH="$PWD/dd"; RESULTS_DIR="$PWD/results"; '
            'mkdir -p "$DERIVED_DATA_PATH" "$RESULTS_DIR"; }\n'
            'trinket_run_env_print() { :; }\ntrinket_track_test_guests() { :; }\n'
        )
        (scripts / "build-freshness.sh").write_text(
            'prepare_generated_inputs() { :; }\nbegin_build_stamps() { :; }\n'
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
                    result = run_captured([str(scripts / "build.sh"), *flags], expected=0)
                    args = (root / "arguments").read_text().splitlines()
                    self.assertEqual(args[:2], ["xcodebuild", "build"])
                    self.assertIn("ENABLE_CODE_COVERAGE=NO", args)
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

    def test_failed_app_test_rebuild_invalidates_previous_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = self.fixture(root)
            (scripts / "build-freshness.sh").write_text(
                (ROOT / "Scripts/build-freshness.sh").read_text()
                + '\nprepare_generated_inputs() { :; }\n'
            )
            env = {**fake_toolchain(root), "TRINKET_ALLOW_HEAVY_LOCAL": "1"}
            command = [str(scripts / "build-for-testing.sh"), "--app-only"]
            result = run_captured(command, env=env, expected=0)
            self.assertEqual(len(list((root / "results").glob("*.stamp"))), 2)
            result = subprocess.run(command, env={**env, "BUILD_STATUS": "65"}, capture_output=True)
            self.assertEqual(result.returncode, 65)
            self.assertFalse(list((root / "results").glob("*.stamp")))
            self.assertFalse(list((root / "results").glob("*.stamp.json")))

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
            runner = scripts / "xcode-runner.sh"
            runner.write_text(runner.read_text().replace('xcode_runner_run() {',
                'xcode_runner_run() { printf "%s" "${TEST_RUNNER_TRINKET_UI_SUCCESS_SCREENSHOTS:-}" > "$PWD/screenshots";'))
            env = {**os.environ, "TRINKET_ALLOW_HEAVY_LOCAL": "1", "TRINKET_ISOLATE": "1",
                   "TRINKET_UI_SUCCESS_SCREENSHOTS": "1", "PATH": f"{root}:{os.environ['PATH']}"}
            run_captured([str(scripts / "test.sh"), "smoke", "--no-build", "SmokeShellTests"], env=env, expected=0)
            args = (root / "arguments").read_text().splitlines()
            self.assertEqual(args[:2], ["xcodebuild", "test-without-building"])
            self.assertEqual((root / "screenshots").read_text(), "1")
            self.assertEqual(args.count("-destination"), 1)
            self.assertIn("id=fixture", args)
            self.assertIn(f"SYMROOT={root}/dd/Build/Products", args)
            self.assertIn(f"OBJROOT={root}/dd/Build/Intermediates.noindex", args)
            for name, body in (
                ("xcodebuild", 'printf "%s\\n" "$@" > arguments\n'
                 'for arg in "$@"; do if [[ "$arg" == SYMROOT=* ]]; then mkdir -p "${arg#SYMROOT=}/Debug-iphoneos/Trinket.app"; fi; done\n'),
                ("xcrun", 'printf "%s\\n" "$@" > installed\n'),
            ):
                write_executable(root / name, '#!/bin/bash\n' + body)
            run_captured([str(scripts / "install-device.sh"), "--device", "fixture", "--no-launch"], env=env, expected=0)
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
            write_executable(root / "swiftlint", '#!/bin/bash\nprintf "%s\\n" "$@" > "$ANALYZE_ARGUMENTS"\necho "$ANALYZE_OUTPUT"\nexit "${ANALYZE_STATUS:-0}"\n')
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
                    result = run_captured([str(scripts / "lint-analyze.sh"), "Probe.swift"], env=env)
                    self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                    args = (root / "arguments").read_text().splitlines()
                    self.assertIn("analyze.", args[args.index("-derivedDataPath") + 1])
                    if build_status == "0":
                        self.assertIn(str((root / "Probe.swift").resolve()), (root / "analyze-arguments").read_text().splitlines())

    def test_generation_checks_live_lock_before_writing_and_recovers_dead_owner(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = self.fixture(root)
            # Exercise the real generate entry point and lock implementation;
            # SDK discovery and content generation are external fixture boundaries.
            (scripts / "run-env.sh").write_text(
                'source Scripts/lib/lock.sh\n'
                'trinket_run_env_init() { TRINKET_GENERATE_LOCK_DIR="$PWD/generation.lock"; }\n'
            )
            (scripts / "content_codegen.py").write_text(
                'import os\nfrom pathlib import Path\n'
                'owner = int(Path("generation.lock/pid").read_text())\n'
                'os.kill(owner, 0)\n'
                'Path("generated").write_text("complete")\n'
            )
            env = {**fake_toolchain(root), "SDKROOT": str(root),
                   "DEVELOPER_DIR": str(root / "Developer"),
                   "TRINKET_GENERATE_LOCK_TIMEOUT_SECONDS": "0"}
            lock = root / "generation.lock"
            lock.mkdir()
            owner = lock / "pid"
            live = str(os.getpid()) + "\n"
            owner.write_text(live)
            command = [str(scripts / "generate.sh"), "--skip-xcodegen"]
            result = run_captured(command, env=env, expected=1, timeout=5)
            self.assertIn("Lock timed out", result.stderr)
            self.assertEqual(owner.read_text(), live)
            self.assertFalse((root / "generated").exists())

            owner.write_text("99999999\n")
            run_captured(command, env=env, expected=0, timeout=5)
            self.assertEqual((root / "generated").read_text(), "complete")
            self.assertFalse(lock.exists())

    def test_failed_generation_does_not_mark_new_inputs_fresh(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Scripts").mkdir()
            for name in ("build-freshness.sh", "build-inputs.env", "lib/generated-paths.sh", "config/generated-paths.tsv"):
                (root / "Scripts" / name).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, root / "Scripts" / name)
            write_executable(root / 'Scripts/prepare-assets.sh', '#!/bin/bash\n[[ "$*" == "--heal" ]] && exit 0\n[[ "$*" == "--check --outputs-only" ]] || exit 9\n')
            write_executable(root / "Scripts/generate.sh", '#!/bin/bash\nexit "${GENERATION_STATUS:-0}"\n')
            command = """
unset TRINKET_SHARED_DERIVED_DATA SKIP_GENERATE
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
            run_captured(["bash", "-eu", "-c", command], cwd=root, expected=0)


    def test_simulator_tenants_share_generation_without_releasing_parent_resources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Scripts/lib").mkdir(parents=True)
            for name in ("build-freshness.sh", "build-inputs.env", "lib/lock.sh", "lib/generated-paths.sh", "config/generated-paths.tsv"):
                (root / "Scripts" / name).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, root / "Scripts" / name)
            write_executable(
                root / 'Scripts/prepare-assets.sh',
                '#!/bin/bash\n[[ "$*" == "--heal" ]] && exit 0\n[[ "$*" == "--check --outputs-only" ]] || exit 9\nprintf checked >> asset-checks\n',
            )
            write_executable(root / "Scripts/generate.sh", '#!/bin/bash\nsleep 1\necho generated >> calls\n')
            command = """
source Scripts/lib/lock.sh
source Scripts/build-freshness.sh
export TRINKET_SHARED_DERIVED_DATA="$PWD/shared"
content_generation_inputs=(input); project_generation_inputs=(project); asset_generation_inputs=(asset)
touch input project asset
trap 'status=$?; echo released >> parent-resources; exit "$status"' EXIT
prepare_generated_inputs human & first=$!
prepare_generated_inputs agent & second=$!
wait "$first"; wait "$second"
[[ $(wc -l < calls) -eq 1 ]] || exit 1
[[ ! -e parent-resources ]] || exit 1
[[ ! -d shared/.generated-inputs.lock ]] || exit 1
prepare_generated_inputs another-agent
[[ $(wc -l < calls) -eq 1 ]] || exit 1
printf changed > asset
prepare_generated_inputs human
prepare_generated_inputs agent
[[ $(wc -l < calls) -eq 2 ]] || exit 1
"""
            run_captured(["bash", "-eu", "-c", command], cwd=root, expected=0)
            self.assertEqual((root / "parent-resources").read_text(), "released\n")

    def test_preparation_timeout_preserves_another_subshells_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Scripts/lib").mkdir(parents=True)
            for name in ("build-freshness.sh", "build-inputs.env", "lib/lock.sh", "lib/generated-paths.sh", "config/generated-paths.tsv"):
                (root / "Scripts" / name).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, root / "Scripts" / name)
            write_executable(root / 'Scripts/prepare-assets.sh', '#!/bin/bash\n[[ "$*" == "--heal" ]] && exit 0\n[[ "$*" == "--check --outputs-only" ]] || exit 9\n')
            command = """
source Scripts/lib/lock.sh
source Scripts/build-freshness.sh
unset BASHPID
export TRINKET_SHARED_DERIVED_DATA="$PWD/shared"
(
  trinket_dir_lock_acquire "$PWD/shared/.generated-inputs.lock" 2
  touch ready
  while [[ ! -f done ]]; do sleep 0.1; done
) & holder=$!
trap 'status=$?; touch done; wait "$holder"; exit "$status"' EXIT
while [[ ! -f ready ]]; do sleep 0.1; done
[[ $(cat shared/.generated-inputs.lock/pid) == "$holder" ]] || exit 11
if TRINKET_GENERATE_LOCK_TIMEOUT_SECONDS=0 prepare_generated_inputs agent; then exit 1; fi
[[ -d shared/.generated-inputs.lock ]] || exit 12
touch done
wait "$holder"
[[ ! -d shared/.generated-inputs.lock ]] || exit 13
"""
            run_captured(["bash", "-eu", "-c", command], cwd=root, timeout=10, expected=0)

    def test_shared_generation_reuses_a_matching_existing_tenant_stamp(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Scripts/lib").mkdir(parents=True)
            for name in ("build-freshness.sh", "build-inputs.env", "lib/lock.sh", "lib/generated-paths.sh", "config/generated-paths.tsv"):
                (root / "Scripts" / name).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, root / "Scripts" / name)
            write_executable(root / 'Scripts/prepare-assets.sh', '#!/bin/bash\n[[ "$*" == "--heal" ]] && exit 0\n[[ "$*" == "--check --outputs-only" ]] || exit 9\n')
            write_executable(root / "Scripts/generate.sh", '#!/bin/bash\necho unexpected > calls\nexit 9\n')
            command = """
source Scripts/lib/lock.sh
source Scripts/build-freshness.sh
content_generation_inputs=(input); project_generation_inputs=(project); asset_generation_inputs=(asset)
touch input project asset
touch_generate_stamp human
export TRINKET_SHARED_DERIVED_DATA="$PWD/shared"
prepare_generated_inputs human
prepare_generated_inputs agent
[[ ! -e calls ]] || exit 1
[[ -f shared/GeneratedInputs/.last-generate.stamp ]] || exit 1
"""
            run_captured(["bash", "-eu", "-c", command], cwd=root, expected=0)

    def test_tool_updates_leave_pins_untouched_after_download_or_hash_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            scripts.mkdir()
            for name in ("update-tools.sh", "tool-versions.env"):
                shutil.copy2(ROOT / "Scripts" / name, scripts)
            pins = scripts / "tool-versions.env"
            initial = pins.read_bytes()
            write_executable(root / "curl", '#!/bin/bash\nif [[ "$*" == *api.github.com* ]]; then echo \'{"tag_name":"999.0.0"}\'; exit 0; fi\nexit "$DOWNLOAD_STATUS"\n')
            write_executable(root / "shasum", '#!/bin/bash\nexit 7\n')
            for download, expected in ((22, 22), (0, 7)):
                result = run_captured([str(scripts / "update-tools.sh"), "--apply"], env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}", "DOWNLOAD_STATUS": str(download)})
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
                    result = run_captured([str(scripts / name), *args])
                    self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                    self.assertIn(message, result.stdout + result.stderr)



if __name__ == "__main__":
    unittest.main()
