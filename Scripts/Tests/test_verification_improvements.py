#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts"))
import failure_diagnostics as REPORTER  # noqa: E402
from script_test_support import ScriptRegressionTestCase


class VerificationImprovementsTests(ScriptRegressionTestCase):
    def test_handoff_dry_run_and_execution_share_cheap_slice_registry(self) -> None:
        config = (ROOT / "Scripts" / "config" / "cheap-slices.txt").read_text(encoding="utf-8")
        registry = [
            line.split("#", 1)[0].strip()
            for line in config.splitlines()
            if line.split("#", 1)[0].strip()
        ]
        self.assertEqual(
            registry,
            [
                "./Scripts/check-module-boundaries.sh",
                "./Scripts/check-api-bans.sh",
                "./Scripts/release-notes.sh validate",
                "./Scripts/check-artwork-budget.sh",
            ],
        )
        lib = (ROOT / "Scripts" / "lib" / "cheap-slices.sh").read_text(encoding="utf-8")
        self.assertIn("trinket_cheap_slice_commands", lib)
        self.assertIn("trinket_run_cheap_slices", lib)
        self.assertIn("--dry-run", lib)
        self.assertIn("cheap-slices.txt", lib)
        handoff = (ROOT / "Scripts" / "handoff.sh").read_text(encoding="utf-8")
        self.assertIn("trinket_run_cheap_slices --dry-run", handoff)
        self.assertIn("trinket_run_cheap_slices", handoff)
        # Dry-run must include cheap slices in order after plan.
        result = subprocess.run(
            [str(ROOT / "Scripts" / "handoff.sh"), "--dry-run", "--paths", "Docs/Platform/Verification.md"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        planned = [line.strip() for line in result.stdout.splitlines() if line.startswith("  ")]
        # Docs scope should contain docs check plus 4 cheap slices in registry order.
        self.assertIn("python3 ./Scripts/check-docs.py", planned)
        cheap_positions = [planned.index(cmd) for cmd in registry]
        self.assertEqual(cheap_positions, sorted(cheap_positions))
        self.assertEqual(planned[-4:], registry)
        # ci-gate --fast must also source same registry.
        gate = (ROOT / "Scripts" / "ci-gate.sh").read_text(encoding="utf-8")
        self.assertIn("cheap-slices.sh", gate)
        self.assertIn("trinket_run_cheap_slices", gate)

    def test_mixed_script_and_docs_runs_docs_once(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Scripts/build.sh",
                "Docs/Platform/Verification.md",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        planned = [line.strip() for line in result.stdout.splitlines() if line.startswith("  ")]
        # Mixed scope must contain docs once and scripts with --skip-docs once.
        self.assertEqual(planned.count("python3 ./Scripts/check-docs.py"), 1)
        self.assertIn("./Scripts/test-scripts.sh --skip-docs", planned)
        self.assertNotIn("./Scripts/test-scripts.sh", [p for p in planned if p == "./Scripts/test-scripts.sh"])

    def test_plain_script_scope_still_validates_docs(self) -> None:
        result = subprocess.run(
            [str(ROOT / "Scripts" / "handoff.sh"), "--dry-run", "--paths", "Scripts/build.sh"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        planned = [line.strip() for line in result.stdout.splitlines() if line.startswith("  ")]
        # Plain script scope validates docs via test-scripts.sh default (no --skip-docs) but also shows cheap slices.
        self.assertIn("./Scripts/test-scripts.sh", planned)
        self.assertNotIn("./Scripts/test-scripts.sh --skip-docs", planned)
        # Ensure cheap slices still present; docs not separately listed for plain script is OK because test-scripts.sh runs it internally,
        # but the plan must not have duplicate docs entry.
        self.assertEqual(planned.count("python3 ./Scripts/check-docs.py"), 0)

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

    def test_artifact_retention_is_seven_days(self) -> None:
        tests = (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
        restore = (ROOT / ".github" / "actions" / "restore-and-build" / "action.yml").read_text(encoding="utf-8")
        self.assertNotRegex(tests, r"retention-days:\s*1\b")
        self.assertNotRegex(restore, r"retention-days:\s*1\b")
        self.assertIn("retention-days: 7", tests)
        self.assertIn("retention-days: 7", restore)
