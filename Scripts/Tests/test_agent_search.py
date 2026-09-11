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
