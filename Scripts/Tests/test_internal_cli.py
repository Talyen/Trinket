#!/usr/bin/env python3

"""Unit coverage for Scripts/internal/cli.py shared Python scaffolding."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from script_test_support import ROOT

from internal.cli import ROOT as CLI_ROOT, die, load_sibling, read_env_arrays, repo_root, validate_repo_paths


class InternalCliTests(unittest.TestCase):
    def test_repo_root_matches_test_support(self) -> None:
        self.assertEqual(CLI_ROOT, ROOT)
        self.assertEqual(repo_root(), ROOT)

    def test_die_reports_and_exits(self) -> None:
        with self.assertRaisesRegex(SystemExit, "1"):
            try:
                die("broken", "Usage: x")
            except SystemExit as error:
                self.assertEqual(error.code, 1)
                raise

    def test_read_env_arrays_matches_bash_sourcing(self) -> None:
        import subprocess

        names = [
            "TRINKET_CONTENT_GENERATION_INPUTS",
            "TRINKET_ASSET_GENERATION_INPUTS",
            "TRINKET_PROJECT_GENERATION_INPUTS",
        ]
        parsed = read_env_arrays(ROOT / "Scripts/build-inputs.env", names)
        script = (
            'source "$1"; printf "%s\\n" "${TRINKET_CONTENT_GENERATION_INPUTS[@]}" '
            '"${TRINKET_ASSET_GENERATION_INPUTS[@]}" "${TRINKET_PROJECT_GENERATION_INPUTS[@]}"'
        )
        expected = subprocess.check_output(
            ["bash", "-eu", "-c", script, "_", str(ROOT / "Scripts/build-inputs.env")],
            text=True,
        ).splitlines()
        actual: list[str] = []
        for name in names:
            actual.extend(parsed[name])
        self.assertEqual(actual, expected)
        # Quoting is unwrapped, not preserved.
        self.assertIn("Raw Assets", parsed["TRINKET_ASSET_GENERATION_INPUTS"])
        self.assertIn("*.xctestplan", parsed["TRINKET_PROJECT_GENERATION_INPUTS"])

    def test_read_env_arrays_rejects_expansion_and_missing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            env = Path(directory) / "test.env"
            env.write_text('WANT=(a "b c")\nEXPANDED=(a $HOME)\n')
            self.assertEqual(read_env_arrays(env, ["WANT"]), {"WANT": ("a", "b c")})
            with self.assertRaises(ValueError):
                read_env_arrays(env, ["EXPANDED"])
            with self.assertRaises(ValueError):
                read_env_arrays(env, ["ABSENT"])
            env.write_text('UNTERMINATED=(a\n')
            with self.assertRaises(ValueError):
                read_env_arrays(env, ["UNTERMINATED"])

    def test_validate_repo_paths(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "ok.txt").write_text("x")
            (root / "sub").mkdir()
            self.assertEqual(validate_repo_paths(["ok.txt"], root), ["ok.txt"])
            absolute = str(root / "ok.txt")
            self.assertEqual(validate_repo_paths([absolute], root), [absolute])
            for bad in ("../outside.txt", "sub", "/definitely-outside-repo.txt"):
                with self.subTest(bad=bad):
                    with self.assertRaises(ValueError):
                        validate_repo_paths([bad], root)

    def test_load_sibling_loads_hyphenated_modules(self) -> None:
        module = load_sibling("cli_test_links", "check-links.py")
        self.assertTrue(hasattr(module, "markdown_files"))
        with self.assertRaises(RuntimeError):
            load_sibling("cli_test_missing", "does-not-exist.py")


if __name__ == "__main__":
    unittest.main()
