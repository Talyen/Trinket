from __future__ import annotations

import contextlib
import io
import subprocess
import tempfile
import unittest
from pathlib import Path

from script_test_support import load_script

SEARCH = load_script("agent_search", "agent-search.py")


class AgentSearchTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory(prefix="agent search ")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.write("Scripts/config/generated-paths.tsv", "content|Packages/Game/Sources/Catalog.swift\n")
        self.write(".gitignore", ".DerivedData/\n")

    def write(self, path: str, text: str) -> None:
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text)

    def search(self, *args: str) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = SEARCH.main(list(args), root=self.root)
        return status, output.getvalue()

    def test_modes_keep_generated_tests_and_ignored_artifacts_out_of_source_discovery(self) -> None:
        files = {
            "Packages/Game/Sources/Rules.swift": "needle\n",
            "Packages/Game/Sources/Catalog.swift": "needle\n",
            "Packages/Game/Sources/New.generated.swift": "needle\n",
            "Packages/Game/Tests/RulesTests.swift": "needle\n",
            "Packages/Game/Sources/GameTestSupport/Fixture.swift": "needle\n",
            "Docs/Rules.md": "needle\n",
            ".DerivedData/Build.swift": "needle\n",
        }
        for path, content in files.items():
            self.write(path, content)
        subprocess.run(["git", "add", "Packages", "Docs", ".gitignore", "Scripts"], cwd=self.root, check=True)
        self.write("Packages/Game/Sources/New Rule.swift", "needle\n")
        (self.root / "Packages/Game/Sources/Link.swift").symlink_to(self.root / "Docs/Rules.md")
        expected = {"source": (2, "New Rule.swift"), "tests": (2, "Fixture.swift"),
                    "docs": (1, "Rules.md"), "generated": (2, "Catalog.swift")}
        for mode, (count, example) in expected.items():
            with self.subTest(mode=mode):
                status, output = self.search("needle", "--mode", mode)
                self.assertEqual(status, 0)
                self.assertIn(f"Matched {count} lines in {count} files", output)
                self.assertIn(example, output)
                self.assertNotIn("Build.swift", output)
                self.assertNotIn("Link.swift", output)
        status, output = self.search("needle", "--scope", "Packages/Game/Sources/New Rule.swift")
        self.assertEqual(status, 0)
        self.assertIn("Matched 1 lines in 1 files", output)

    def test_bounded_results_report_all_omissions_and_allow_complete_narrow_reads(self) -> None:
        self.write("Rules.swift", "needle\n" * 5 + "needle " + "x" * 600 + "\n")
        self.write("Other.swift", "needle\n")
        _, output = self.search("needle", "--limit", "1")
        self.assertIn("Matched 7 lines in 2 files; omitted 1 files", output)
        _, output = self.search("needle", "--scope", "Rules.swift", "--excerpts", "--limit", "2", "--context", "0")
        self.assertIn("Matched 6 lines in 1 files; omitted 4 excerpt lines", output)
        _, output = self.search("needle", "--scope", "Rules.swift", "--excerpts", "--limit", "8")
        self.assertIn("omitted 0 excerpt lines; shortened 1 lines", output)
        self.assertTrue(all(len(line) <= 300 for line in output.splitlines()))
        status, output = self.search("absent", "--scope", "Rules.swift")
        self.assertEqual(status, 1)
        self.assertIn("Matched 0 lines", output)

    def test_patterns_and_paths_are_arguments_not_shell_or_rg_options(self) -> None:
        self.write("Rules.swift", "--help $(touch unwanted) `command`\n")
        status, output = self.search("-F", "--", "--help $(touch unwanted) `command`")
        self.assertEqual(status, 0)
        self.assertIn("Matched 1 lines", output)
        self.assertFalse((self.root / "unwanted").exists())
        for scope in ("../outside", str(self.root)):
            with self.subTest(scope=scope), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    self.search("needle", "--scope", scope)

    def test_documentation_orders_roles_before_file_and_excerpt_limits(self) -> None:
        expected = [
            ".cursor/rules/colors.mdc", "Docs/Platform/Verification.md", "Scripts/Reference.md",
            ".agents/knowledge/patterns/example.md", ".agents/skills/example/SKILL.md",
            "Docs/Audits/README.md", ".agents/FRICTION_LOG.md", ".agents/evals/example.md",
            "Docs/Audits/Proposals.md", "Docs/Plans/Example.md",
        ]
        for name in reversed(expected):
            self.write(name, "needle first\nneedle second\n")
        for extra, limit, omitted in (([], "3", "7 files"), (["--excerpts", "--context", "0"], "6", "14 excerpt lines")):
            with self.subTest(extra=extra):
                status, output = self.search("needle", "--mode", "docs", "--limit", limit, *extra)
                self.assertEqual(status, 0)
                self.assertIn("Matched 20 lines in 10 files", output)
                self.assertIn(f"omitted {omitted}", output)
                positions = [output.index(name + ":") for name in expected[:3]]
                self.assertEqual(positions, sorted(positions))
                for name in expected[3:]:
                    self.assertNotIn(name + ":", output)
        _, output = self.search("needle", "--mode", "docs", "--limit", "30", "--excerpts", "--context", "0")
        positions = [output.index(name + ":1: needle first") for name in expected]
        self.assertEqual(positions, sorted(positions))
        for name in expected:
            self.assertLess(output.index(name + ":1:"), output.index(name + ":2:"))
        status, output = self.search("needle", "--mode", "docs", "--scope", "Docs/Plans")
        self.assertEqual(status, 0)
        self.assertIn("Matched 2 lines in 1 files; omitted 0 files", output)
        status, _ = self.search("needle", "--scope", ".cursor/rules")
        self.assertEqual(status, 1)

    def test_invalid_search_expression_is_reported_as_an_error(self) -> None:
        self.write("Rules.swift", "needle\n")
        with contextlib.redirect_stderr(io.StringIO()) as errors:
            status, output = self.search("[")
        self.assertEqual(status, 2)
        self.assertIn("regex parse error", errors.getvalue())
        self.assertNotIn("Matched", output)

    def test_identifier_owner_precedes_references_before_file_and_excerpt_limits(self) -> None:
        self.write("AReference.swift", "BattleState caller\n")
        self.write("State/BattleState.swift", "struct BattleState {}\nBattleState second\n")
        for extra in ([], ["--excerpts", "--context", "0"]):
            _, output = self.search("BattleState", "--limit", "1", *extra)
            self.assertIn("State/BattleState.swift", output)
            self.assertNotIn("AReference.swift", output)
        _, output = self.search("BattleState.*", "--limit", "1")
        self.assertIn("AReference.swift", output)
        _, output = self.search("battlestate", "-i", "--limit", "1")
        self.assertIn("State/BattleState.swift", output)
        self.write("Docs/A.md", "BattleState\n")
        self.write("Docs/BattleState.md", "BattleState\n")
        _, output = self.search("BattleState", "--mode", "docs", "--limit", "1")
        self.assertIn("Docs/A.md", output)
        self.assertNotIn("Docs/BattleState.md", output)

    def test_filename_search_uses_filtered_inventory_without_reading_contents(self) -> None:
        for name in ("Sources/Owner.swift", "Sources/Other Owner.swift", "Tests/Owner.swift",
                     "Docs/Owner.md", "Sources/Owner.generated.swift", ".DerivedData/Owner.swift"):
            self.write(name, "no symbol matches\n")
        _, output = self.search("Owner", "--files", "--limit", "1")
        self.assertIn("Sources/Owner.swift", output)
        self.assertIn("Matched 2 files; omitted 1 files", output)
        for mode, expected in (("tests", "Tests/Owner.swift"), ("docs", "Docs/Owner.md"),
                               ("generated", "Sources/Owner.generated.swift")):
            _, output = self.search("Owner", "--files", "--mode", mode)
            self.assertIn(expected, output)
            self.assertIn("Matched 1 files; omitted 0 files", output)
        _, output = self.search("Other Owner.swift", "--files", "-F", "--scope", "Sources")
        self.assertIn("Sources/Other Owner.swift", output)
        self.assertNotIn("Sources/Owner.swift", output)
        status, _ = self.search("Absent", "--files")
        self.assertEqual(status, 1)
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(self.search("[", "--files")[0], 2)
            with self.assertRaises(SystemExit):
                self.search("Owner", "--files", "--excerpts")
