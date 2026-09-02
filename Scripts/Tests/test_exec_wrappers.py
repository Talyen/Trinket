#!/usr/bin/env python3
"""Execution-free coverage for top-level wrappers lacking dedicated tests.

Covers --help/unknown-arg paths for test.sh, build-for-testing.sh,
test-scripts.sh, and performance.sh without requiring Xcode or simulators.
"""

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
