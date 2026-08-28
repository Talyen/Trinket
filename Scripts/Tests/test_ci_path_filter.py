#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load_filter():
    spec = importlib.util.spec_from_file_location(
        "ci_path_filter", ROOT / "Scripts" / "ci-path-filter.py"
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load ci-path-filter.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["ci_path_filter"] = module
    spec.loader.exec_module(module)
    return module


class CIPathFilterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.filter = load_filter()

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
        self.assertFalse(match(".github/workflows/tests.yml"))
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
        self.assertTrue(match("Scripts/prepare-art-assets.sh"))
        self.assertFalse(match("Scripts/lint-analyze.sh"))
        self.assertFalse(match("Trinket/App/TrinketApp.swift"))

    def test_classify_docs_only_is_false(self) -> None:
        code, assets, infra = self.filter.classify(
            ["Docs/Platform/Verification.md", "Scripts/README.md"]
        )
        self.assertFalse(code)
        self.assertFalse(assets)
        self.assertFalse(infra)

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
        text = (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
        composite = (ROOT / ".github" / "actions" / "checkout-inputs" / "action.yml").read_text(encoding="utf-8")
        combined = text + composite
        self.assertIn("sparse-checkout-cone-mode: true", combined)
        self.assertIn("test -f project.yml", combined)
        self.assertIn("test -f Smoke.xctestplan", combined)
        self.assertIn("test -f FullUI.xctestplan", combined)
        self.assertIn("test -f BattlePerformance.xctestplan", combined)
        self.assertNotIn("checkout-ci", text)
        # tests.yml should delegate to composite, not inline checkout
        self.assertIn("checkout-inputs", text)

    def test_test_job_reads_preboot_status(self) -> None:
        text = (
            ROOT / ".github" / "actions" / "test-job" / "action.yml"
        ).read_text(encoding="utf-8")
        self.assertIn('status="$(cat "$RUNNER_TEMP/trinket-sim-preboot.status")"', text)
        self.assertIn("Simulator preboot failed", text)


if __name__ == "__main__":
    unittest.main()
