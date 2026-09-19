#!/usr/bin/env python3

"""Unit coverage for Scripts/internal/cli.py shared Python scaffolding."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from script_test_support import ROOT

from internal.cli import ROOT as CLI_ROOT, die, load_sibling, read_env_arrays, read_json, repo_root, validate_repo_paths


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

    def test_read_json_loads_and_names_decode_failures(self) -> None:
        import json

        with tempfile.TemporaryDirectory() as directory:
            good = Path(directory) / "good.json"
            good.write_text(json.dumps({"a": [1, 2]}))
            self.assertEqual(read_json(good), {"a": [1, 2]})
            bad = Path(directory) / "bad.json"
            bad.write_text("{nope")
            with self.assertRaises(json.JSONDecodeError) as caught:
                read_json(bad)
            self.assertIn("bad.json", str(caught.exception))
            with self.assertRaises(OSError):
                read_json(Path(directory) / "missing.json")

    def test_diagnostic_limits_match_bash_sourcing(self) -> None:
        import subprocess

        from internal.diagnostics import diagnostic_limits

        env = ROOT / "Scripts" / "config" / "diagnostic-limits.env"
        expected: dict[str, str] = {}
        for line in env.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, raw = line.split("=", 1)
            int(raw)  # schema: every value must be an integer both parsers agree on
            expected[key] = raw
        self.assertTrue(expected)
        names = sorted(expected)
        script = 'source "$1"; for name in "${@:2}"; do printf "%s=%s\\n" "$name" "${!name}"; done'
        actual = subprocess.check_output(
            ["bash", "-eu", "-c", script, "_", str(env), *names], text=True
        ).splitlines()
        self.assertEqual(actual, [f"{key}={expected[key]}" for key in names])
        self.assertEqual(diagnostic_limits.MAX_ISSUES, int(expected["TRINKET_DIAGNOSTIC_MAX_ISSUES"]))


if __name__ == "__main__":
    unittest.main()
