#!/usr/bin/env python3
from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/ci-path-filter.py',
)


import ast
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

from script_test_support import ROOT, load_script


class CIPathFilterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.filter = load_script("ci_path_filter", "ci-path-filter.py")

    def test_compare_includes_rename_source_and_fails_closed_at_file_limit(self) -> None:
        cases = [
            ([{"filename": "Docs/archived.swift", "previous_filename": "Trinket/App.swift"}],
             ["Docs/archived.swift", "Trinket/App.swift"]),
            ([{"filename": f"Docs/{index}.md"} for index in range(299)],
             [f"Docs/{index}.md" for index in range(299)]),
            ([{"filename": f"Docs/{index}.md"} for index in range(300)], None),
        ]
        for files, expected in cases:
            with self.subTest(count=len(files)), patch.object(self.filter.urllib.request, "urlopen") as request:
                response = io.StringIO(json.dumps({"files": files}))
                response.headers = {"Link": '<https://api.github.com/next>; rel="next"'}
                next_page = io.StringIO('{"commits": []}')
                next_page.headers = {}
                request.side_effect = [response, next_page]
                self.assertEqual(self.filter.compare_filenames("owner/repo", "before", "after", "token"), expected)
                request.assert_called_once()

    def test_code_globs_match_app_and_build_scripts(self) -> None:
        match = self.filter.is_code_path
        self.assertTrue(match("Trinket/App/TrinketApp.swift"))
        self.assertTrue(match("Packages/BattleEngine/Sources/BattleEngine/Foo.swift"))
        self.assertTrue(match("project.yml"))
        self.assertTrue(match("Smoke.xctestplan"))
        self.assertTrue(match("Scripts/build-for-testing.sh"))
        self.assertTrue(match("Scripts/test.sh"))
        self.assertTrue(match("Scripts/generate.sh"))
        self.assertTrue(match("Scripts/ensure-simulator.sh"))
        self.assertTrue(match("Scripts/stage-ci-test-artifact.sh"))
        self.assertTrue(match("Scripts/run-env.sh"))
        self.assertTrue(match("Scripts/ci-path-filter.py"))
        self.assertTrue(match("Scripts/lib/smoke-classes.sh"))
        self.assertFalse(match("Scripts/lint-analyze.sh"))
        self.assertFalse(match("Scripts/release-notes-user.py"))
        self.assertTrue(match(".github/workflows/tests.yml"))
        self.assertFalse(match("Docs/Platform/Verification.md"))
        self.assertFalse(match("CHANGELOG.md"))

    def test_infra_globs_match_scripts_and_workflows(self) -> None:
        match = self.filter.is_infra_path
        self.assertTrue(match("Scripts/lint-analyze.sh"))
        self.assertTrue(match("Scripts/ci-path-filter.py"))
        self.assertTrue(match(".github/workflows/tests.yml"))
        self.assertTrue(match(".swiftlint.yml"))
        self.assertFalse(match("Scripts/README.md"))
        self.assertFalse(match("Trinket/App/TrinketApp.swift"))

    def test_asset_globs_match_prepare_scripts(self) -> None:
        match = self.filter.is_asset_path
        self.assertTrue(match("ArtManifest/curated-assets.tsv"))
        self.assertTrue(match("Raw Assets/Art/foo.png"))
        prepare_scripts = sorted((ROOT / "Scripts").glob("prepare-*.sh"))
        self.assertGreater(len(prepare_scripts), 0)
        for script in prepare_scripts:
            with self.subTest(script=script.name):
                self.assertTrue(match(str(script.relative_to(ROOT))))
        self.assertTrue(match("Scripts/prepare-app-icon.sh"))
        self.assertFalse(match("Scripts/lint-analyze.sh"))
        self.assertFalse(match("Trinket/App/TrinketApp.swift"))

    def test_prepare_assets_is_asset_and_infra(self) -> None:
        code, assets, infra = self.filter.classify(["Scripts/prepare-assets.sh"])
        self.assertTrue(code)
        self.assertTrue(assets)
        self.assertTrue(infra)

    def test_generation_helpers_route_local_and_ci_verification(self) -> None:
        cases = (("internal/content/content_codegen_modifiers.py", False), ("internal/content/content_codegen_triggers.py", False),
                 ("internal/content/trigger_families/index.json", False), ("prepare-assets.sh", True), ("lib/media-assets.sh", True))
        for name, assets in cases:
            with self.subTest(path=name):
                path = "Scripts/" + name
                self.assertEqual(self.filter.classify([path]), (True, assets, True))
                output = subprocess.check_output(
                    [str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--paths", path], cwd=ROOT, text=True,
                )
                planned = [line.strip() for line in output.splitlines() if line.startswith("  ")]
                self.assertIn("./Scripts/generate.sh" + (" --assets" if assets else ""), planned)
                self.assertIn("./Scripts/assert-generated-output.sh --idempotent" + (" --assets" if assets else ""), planned)

    def test_build_contract_inputs_and_documentation(self) -> None:
        cases = {
            "StoreKit/Trinket.storekit": (True, False, False),
            "Scripts/tool-versions.env": (True, False, True),
            "Scripts/build-inputs.env": (True, False, True),
            "Scripts/xcode-runner.sh": (True, False, True),
            ".github/actions/restore-and-build/action.yml": (True, False, True),
            ".github/actions/test-job/action.yml": (True, False, True),
            ".github/actions/setup-trinket/action.yml": (True, False, True),
            ".github/workflows/ci.yml": (True, False, True),
            "Packages/TrinketCore/Package.swift": (True, False, False),
            "Packages/TrinketCore/README.md": (False, False, False),
            "ArtManifest/README.md": (False, False, False),
            "Docs/Platform/Verification.md": (False, False, False),
            "Scripts/README.md": (False, False, False),
        }
        for path, expected in cases.items():
            with self.subTest(path=path):
                self.assertEqual(self.filter.classify([path]), expected)

    def test_classify_lint_script_only_is_infra(self) -> None:
        code, assets, infra = self.filter.classify(["Scripts/lint-analyze.sh"])
        self.assertFalse(code)
        self.assertFalse(assets)
        self.assertTrue(infra)

    def test_classify_build_script_is_code_and_infra(self) -> None:
        code, assets, infra = self.filter.classify(["Scripts/build-for-testing.sh"])
        self.assertTrue(code)
        self.assertFalse(assets)
        self.assertTrue(infra)

    def test_changes_yml_has_no_full_checkout(self) -> None:
        text = (ROOT / ".github" / "workflows" / "changes.yml").read_text(encoding="utf-8")
        self.assertIn("ci-path-filter.py", text)
        self.assertIn("outputs.infra", text)
        self.assertNotIn("actions/checkout@", text)
        self.assertNotIn("dorny/paths-filter@", text)

    def test_tests_yml_sparse_checkout_asserts_root_build_inputs(self) -> None:
        checkout = (
            ROOT / ".github" / "actions" / "checkout-trinket" / "action.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("sparse-checkout-cone-mode: true", checkout)
        self.assertIn("test -f project.yml", checkout)
        self.assertIn("test -f Smoke.xctestplan", checkout)
        self.assertIn("test -f FullUI.xctestplan", checkout)
        self.assertIn("test -f BattlePerformance.xctestplan", checkout)
        self.assertNotIn("checkout-ci", checkout)
        workflow = (ROOT / ".github" / "workflows" / "tests.yml").read_text(
            encoding="utf-8"
        )
        sparse_blocks = re.findall(r"sparse-checkout: \|\n((?:            \S.*\n)+)", workflow)
        self.assertGreater(len(sparse_blocks), 0)
        for block in sparse_blocks:
            roots = block.split()
            self.assertTrue({"Scripts", "Packages", "Trinket", "StoreKit", ".github"}.issubset(roots))
            self.assertNotIn("Raw Assets", block)
        self.assertNotIn("checkout-ci", workflow)

    def test_test_job_reads_preboot_status(self) -> None:
        text = (
            ROOT / ".github" / "actions" / "test-job" / "action.yml"
        ).read_text(encoding="utf-8")
        self.assertIn('status="$(cat "$RUNNER_TEMP/trinket-sim-preboot.status")"', text)
        self.assertIn("Simulator preboot failed", text)

    def test_standalone_env_parser_matches_internal_parser(self) -> None:
        # changes.yml runs ci-path-filter.py from /tmp with only
        # build-inputs.env beside it, so the module falls back to its
        # vendored parser. Pin the two implementations against each other.
        from internal.cli import read_env_arrays

        names = [
            "TRINKET_CONTENT_GENERATION_INPUTS",
            "TRINKET_ASSET_GENERATION_INPUTS",
            "TRINKET_PROJECT_GENERATION_INPUTS",
        ]
        env_path = ROOT / "Scripts" / "build-inputs.env"
        self.assertEqual(
            self.filter._standalone_read_env_arrays(env_path, names),
            read_env_arrays(env_path, names),
        )

    def test_standalone_env_parser_rejects_bad_input_like_internal_parser(self) -> None:
        from internal.cli import read_env_arrays

        cases = {
            "missing": ("OTHER=(\na\n)\n", ["WANT"]),
            "unterminated": ("WANT=(\na\n", ["WANT"]),
            "expansion": ("WANT=(\n$a\n)\n", ["WANT"]),
        }
        for label, (body, names) in cases.items():
            with self.subTest(case=label):
                with tempfile.TemporaryDirectory() as tmp:
                    env = Path(tmp) / "build-inputs.env"
                    env.write_text(body, encoding="utf-8")
                    with self.assertRaises(ValueError):
                        read_env_arrays(env, names)
                    with self.assertRaises(ValueError):
                        self.filter._standalone_read_env_arrays(env, names)

    def test_module_loads_standalone_without_internal_package(self) -> None:
        # Reproduce the CI layout: only the script and its env file, with
        # no `internal` package importable, then exercise generation_inputs.
        from internal.cli import read_env_arrays

        with tempfile.TemporaryDirectory() as tmp:
            shutil.copy(ROOT / "Scripts" / "ci-path-filter.py", Path(tmp) / "ci-path-filter.py")
            shutil.copy(ROOT / "Scripts" / "build-inputs.env", Path(tmp) / "build-inputs.env")
            child = (
                "import importlib.util, sys;"
                "spec = importlib.util.spec_from_file_location('ci_standalone', 'ci-path-filter.py');"
                "mod = importlib.util.module_from_spec(spec);"
                "sys.modules['ci_standalone'] = mod;"
                "spec.loader.exec_module(mod);"
                "assert 'internal.cli' not in sys.modules, 'must run without the internal package';"
                "print(repr(mod.generation_inputs()))"
            )
            output = subprocess.check_output(
                [sys.executable, "-c", child],
                cwd=tmp,
                env={"PATH": "/usr/bin:/bin", "SYSTEMROOT": os.environ.get("SYSTEMROOT", "")}
                if os.name == "nt"
                else {"PATH": "/usr/bin:/bin"},
                text=True,
            )
            standalone = ast.literal_eval(output.strip())
            names = [
                "TRINKET_CONTENT_GENERATION_INPUTS",
                "TRINKET_ASSET_GENERATION_INPUTS",
                "TRINKET_PROJECT_GENERATION_INPUTS",
            ]
            parsed = read_env_arrays(ROOT / "Scripts" / "build-inputs.env", names)
            self.assertEqual(
                standalone,
                (
                    parsed[names[0]],
                    parsed[names[1]],
                    parsed[names[2]],
                ),
            )


if __name__ == "__main__":
    unittest.main()
