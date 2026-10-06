#!/usr/bin/env python3
from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/ci-path-filter.py',
    'Scripts/config/generated-paths.tsv',
    'Scripts/handoff.sh',
    '.github/workflows/changes.yml',
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
            ({"files": [{"filename": "Docs/archived.swift", "previous_filename": "Trinket/App.swift"}]},
             ["Docs/archived.swift", "Trinket/App.swift"]),
            ({"files": [{"filename": f"Docs/{index}.md"} for index in range(299)]},
             [f"Docs/{index}.md" for index in range(299)]),
            ({"files": [{"filename": f"Docs/{index}.md"} for index in range(300)]}, None),
            ({"files": []}, []),
            ({}, None),
            ([], None),
            ({"files": [None]}, None),
            ({"files": [{"filename": "Docs/a.md", "status": "renamed"}]}, None),
            ({"files": [{"filename": "Docs/a.md", "previous_filename": 1}]}, None),
            ({"files": [], "truncated": True}, None),
        ]
        for payload, expected in cases:
            with self.subTest(payload=payload), patch.object(self.filter.urllib.request, "urlopen") as request:
                request.return_value = io.StringIO(json.dumps(payload))
                self.assertEqual(self.filter.compare_filenames("owner/repo", "before", "after", "token"), expected)
                request.assert_called_once()

    def test_package_selection_preserves_consumers_and_full_fallback(self):
        graph = {
            'TrinketCore': set(), 'TrinketContent': {'TrinketCore'},
            'BattleEngine': {'TrinketCore', 'TrinketContent'},
            'TrinketPersistence': {'TrinketCore', 'TrinketContent'},
            'TrinketDesignSystem': {'TrinketCore'},
            'TrinketFeatureSupport': {'TrinketCore', 'TrinketDesignSystem', 'BattleEngine'},
            'TrinketBattleFeature': {'TrinketFeatureSupport', 'BattleEngine'},
            'TrinketAppState': {'TrinketPersistence', 'TrinketBattleFeature'},
        }
        select = self.filter.affected_packages
        self.assertEqual(select(['TrinketUITests/Example.swift'], graph), set())
        self.assertEqual(select(['Packages/TrinketPersistence/Sources/Store.swift'], graph),
                         {'TrinketPersistence', 'TrinketAppState'})
        self.assertEqual(select(['Packages/TrinketCore/Sources/Card.swift'], graph), self.filter.all_packages())
        for path in ('Scripts/test.sh', 'Packages/Unknown/Sources/Rule.swift', 'Packages/BattleEngine/Package.swift'):
            self.assertEqual(select([path], graph), self.filter.all_packages())
        self.assertEqual(select(['Packages/TrinketPersistence/Sources/Store.swift'], {}), self.filter.all_packages())

    def test_asset_globs_match_prepare_scripts(self) -> None:
        match = self.filter.is_asset_path
        self.assertTrue(match("ArtManifest/curated-assets.tsv"))
        self.assertTrue(match("ArtManifest/app-icon.tsv"))
        for path in ('Trinket/Media/SFX/sfx_hit.m4a', 'Trinket/Assets.xcassets/hero_knight_card.imageset/Contents.json',
                     'Trinket/AppIcon.icon/icon.json',
                     'Packages/TrinketContent/Sources/TrinketContent/Generated/SFXCatalog.generated.swift'):
            with self.subTest(path=path):
                self.assertTrue(match(path))
        prepare_scripts = sorted((ROOT / "Scripts").glob("prepare-*.sh"))
        self.assertGreater(len(prepare_scripts), 0)
        for script in prepare_scripts:
            with self.subTest(script=script.name):
                self.assertTrue(match(str(script.relative_to(ROOT))))
        self.assertTrue(match("Scripts/prepare-app-icon.sh"))
        self.assertFalse(match("Scripts/lint-analyze.sh"))
        self.assertFalse(match("Trinket/App/TrinketApp.swift"))

    def test_generation_helpers_route_local_and_ci_verification(self) -> None:
        cases = (("internal/content/content_codegen_modifiers.py", False), ("internal/content/content_codegen_triggers.py", False),
                 ("internal/content/trigger_families/index.json", False), ("prepare-assets.sh", True),
                 ("lib/media-assets.sh", True), ("config/full-only-art-kinds.txt", True))
        for name, assets in cases:
            with self.subTest(path=name):
                path = "Scripts/" + name
                self.assertEqual(self.filter.classify([path]), (True, assets, True))
                output = subprocess.check_output(
                    [str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--paths", path], cwd=ROOT, text=True,
                    env={key: value for key, value in os.environ.items()
                         if key not in {'CI', 'GITHUB_ACTIONS', 'TRINKET_ALLOW_HEAVY_LOCAL'}},
                )
                planned = [line.strip() for line in output.splitlines() if line.startswith("  ")]
                self.assertIn("./Scripts/generate.sh", planned)
                self.assertIn("./Scripts/assert-generated-output.sh --idempotent", planned)
                if assets:
                    self.assertIn("./Scripts/ci-assets-gate.sh", planned)

    def test_build_contract_inputs_and_documentation(self) -> None:
        cases = {
            "Trinket/App/TrinketApp.swift": (True, False, False),
            "Packages/BattleEngine/Sources/BattleEngine/Foo.swift": (True, False, False),
            "project.yml": (True, False, False),
            "Smoke.xctestplan": (True, False, False),
            "Scripts/generate.sh": (True, False, True),
            "Scripts/ensure-simulator.sh": (True, False, True),
            "Scripts/stage-ci-test-artifact.sh": (True, False, True),
            "Scripts/lib/smoke-classes.sh": (True, False, True),
            "Scripts/release-notes-user.py": (False, False, True),
            "CHANGELOG.md": (False, False, False),
            ".swiftlint.yml": (False, False, True),
            "Scripts/prepare-assets.sh": (True, True, True),
            "Scripts/lint-analyze.sh": (False, False, True),
            "Scripts/build-for-testing.sh": (True, False, True),
            "StoreKit/Trinket.storekit": (True, False, False),
            "Scripts/tool-versions.env": (True, False, True),
            "Scripts/build-inputs.env": (True, False, True),
            "Scripts/xcode-runner.sh": (True, False, True),
            "Scripts/build-metadata.py": (True, False, True),
            "Scripts/restore-ci-test-products.sh": (True, False, True),
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

    def test_git_hook_changes_select_the_script_gate(self) -> None:
        for hook in ("pre-commit", "pre-push", "commit-msg"):
            with self.subTest(hook=hook):
                self.assertEqual(self.filter.classify([f".githooks/{hook}"]), (hook == "pre-commit", False, True))

    def test_smoke_path_classification(self) -> None:
        smoke_cases = {
            "Trinket/App/TrinketApp.swift": True,
            "TrinketUITests/Smoke/SmokePlayTests.swift": True,
            "Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/BattleView.swift": True,
            "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shine.swift": True,
            "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/Colors.swift": True,
            "StoreKit/Trinket.storekit": True,
            "Smoke.xctestplan": True,
            "Scripts/test.sh": True,
            "Packages/BattleEngine/Sources/BattleEngine/Combatant.swift": False,
            "Packages/TrinketCore/Sources/TrinketCore/Effect.swift": False,
            "Packages/TrinketPersistence/Sources/TrinketPersistence/Save.swift": False,
            "ContentManifest/README.md": False,
            "Docs/Platform/Verification.md": False,
        }
        for path, expected in smoke_cases.items():
            with self.subTest(path=path):
                self.assertEqual(self.filter.is_smoke_path(path), expected)
        self.assertTrue(self.filter.needs_smoke(["Trinket/App/App.swift", "Packages/BattleEngine/Foo.swift"]))
        self.assertFalse(self.filter.needs_smoke(["Packages/BattleEngine/Foo.swift", "Packages/TrinketCore/Bar.swift"]))

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

    def test_minimal_ci_layout_uses_shared_parser_without_checkout(self) -> None:
        from internal.cli import read_env_arrays

        with tempfile.TemporaryDirectory() as tmp:
            shutil.copy(ROOT / "Scripts" / "ci-path-filter.py", Path(tmp) / "ci-path-filter.py")
            shutil.copy(ROOT / "Scripts" / "build-inputs.env", Path(tmp) / "build-inputs.env")
            internal = Path(tmp) / "internal"
            internal.mkdir()
            shutil.copy(ROOT / "Scripts/internal/cli.py", internal / "cli.py")
            child = (
                "import importlib.util, sys;"
                "spec = importlib.util.spec_from_file_location('ci_standalone', 'ci-path-filter.py');"
                "mod = importlib.util.module_from_spec(spec);"
                "sys.modules['ci_standalone'] = mod;"
                "spec.loader.exec_module(mod);"
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
