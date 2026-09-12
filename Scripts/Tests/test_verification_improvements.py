#!/usr/bin/env python3
from __future__ import annotations

import tempfile
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts"))
import failure_diagnostics as REPORTER  # noqa: E402
from script_test_support import ScriptRegressionTestCase


class VerificationImprovementsTests(ScriptRegressionTestCase):
    def test_xctest_assertion_with_incomplete_bundle_is_test_failure(self) -> None:
        import types

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            log = root / "xcodebuild.log"
            log.write_text("Trinket/Play/PlayTests.swift:42: error: XCTAssertTrue failed - value was false\n", encoding="utf-8")
            bundle = root / "missing.xcresult"
            prefix = root / "report"
            args = types.SimpleNamespace(
                result_bundle=str(bundle),
                log=str(log),
                exit_code=65,
                label="PlaySmoke",
                output_prefix=str(prefix),
                defer_terminal_output=True,
            )
            report = REPORTER.build_report(args)
            observations = REPORTER.parse_log(log, 65)
            self.assertTrue(any(obs.kind == "test-failure" and "XCTAssert" in obs.message for obs in observations), observations)
            self.assertNotEqual(report.classification, "build-failure")
            self.assertEqual(report.classification, "test-failure")

    def test_every_unit_package_in_exactly_one_shard(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
        env = (ROOT / "Scripts" / "build-inputs.env").read_text(encoding="utf-8")
        import re

        test_packages_block = re.search(r"TRINKET_TEST_PACKAGES=\((.*?)\)", env, re.S).group(1)
        packages = re.findall(r"^\s+(Trinket\w+|BattleEngine)\b", test_packages_block, re.M)
        # Extract shard package lists — only the unit job includes
        unit_section = workflow.split("name: Unit tests")[1].split("smoke:")[0]
        shard_packages: list[str] = []
        for match in re.finditer(r"packages:\s*([A-Za-z0-9 ]+)", unit_section):
            shard_packages.extend(match.group(1).strip().split())
        self.assertEqual(sorted(set(packages)), sorted(set(shard_packages)))
        self.assertEqual(len(shard_packages), len(set(shard_packages)), "duplicate package across shards")
        self.assertIn("BattleEngine", shard_packages)
        self.assertIn("TrinketCore", shard_packages)
        self.assertIn("TrinketContent", shard_packages)

    def test_concurrency_groups_distinct_by_event_type(self) -> None:
        ci = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        self.assertIn("github.event_name", ci)
        self.assertIn("ci-${{ github.workflow }}-${{ github.ref }}-${{ github.event_name }}", ci)

    def test_workflow_action_pins_are_node24(self) -> None:
        import re

        expected = {
            "actions/checkout": "93cb6efe18208431cddfb8368fd83d5badbf9bfd",
            "actions/cache": "3edfce9056124e459a23f683a21433670d47daca",
            "actions/cache/restore": "3edfce9056124e459a23f683a21433670d47daca",
            "actions/cache/save": "3edfce9056124e459a23f683a21433670d47daca",
            "actions/upload-artifact": "043fb46d1a93c77aae656e7c1c64a875d1fc6a0a",
            "actions/download-artifact": "484a0b528fb4d7bd804637ccb632e47a0e638317",
        }
        # Check all workflow and action files
        files = list((ROOT / ".github" / "workflows").glob("*.yml")) + list((ROOT / ".github" / "actions").glob("**/*.yml"))
        text = "\n".join(p.read_text(encoding="utf-8") for p in files)
        for action, sha in expected.items():
            self.assertIn(sha, text, f"{action} SHA {sha} not found")
        # Ensure old Node20 SHAs are gone
        old_shas = [
            "34e114876b0b11c390a56381ad16ebd13914f8d5",
            "0057852bfaa89a56745cba8c7296529d2fc39830",
            "ea165f8d65b6e75b540449e92b4886f43607fa02",
            "d3f86a106a0bac45b974a628896c90dbdf5c8093",
        ]
        for old in old_shas:
            self.assertNotIn(old, text)
