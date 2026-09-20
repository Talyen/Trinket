from __future__ import annotations

import contextlib
import io
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path

from script_test_support import load_script

DIFF = load_script("agent_diff", "agent-diff.py")


class AgentDiffTests(unittest.TestCase):
    def test_pages_preserve_hunks_and_reject_changed_continuations(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            registry = root / "Scripts/config/generated-paths.tsv"
            registry.parent.mkdir(parents=True)
            registry.write_text("content|Generated\n")
            path = root / "Authored space.swift"
            path.write_text("".join(f"line {i}\n" for i in range(90)))
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            lines = path.read_text().splitlines()
            for i in (10, 40, 70):
                lines[i] = f"changed {i}"
            path.write_text("\n".join(lines) + "\n")
            def run(args):
                output = io.StringIO()
                with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                    status = DIFF.main(args, root=root)
                return status, output.getvalue()
            args = ["--max-chars", "400", "--paths", path.name]
            pages = []
            continuation = None
            for _ in range(10):
                status, output = run(args)
                self.assertEqual(status, 0)
                pages.append(output)
                next_line = next((line for line in output.splitlines() if line.startswith("Continue: ")), None)
                if next_line is None:
                    break
                args = shlex.split(next_line.removeprefix("Continue: "))[2:]
                continuation = args
            else:
                self.fail("pagination did not terminate")
            combined = "".join(pages)
            for i in (10, 40, 70):
                self.assertEqual(combined.count(f"+changed {i}\n"), 1)
            self.assertGreater(len(pages), 1)
            path.write_text(path.read_text() + "new change\n")
            self.assertEqual(run(continuation)[0], 2)
            status, output = run(["--max-chars", "1", "--paths", path.name])
            self.assertIn("was not truncated", output)
            self.assertNotIn("+changed", output)
            self.assertIn("+changed 10", run(["--full", "--paths", path.name])[1])

    def test_generated_disclosure_expansion_and_index_boundaries(self) -> None:
        with tempfile.TemporaryDirectory(prefix="agent diff ") as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=root)
            def write(name, value):
                p = root / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(value)
            def read(*args):
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    self.assertEqual(DIFF.main(list(args), root=root), 0)
                return output.getvalue()
            git("init", "-q")
            write("Scripts/config/generated-paths.tsv", "content|Generated\n")
            write("Authored file.swift", "baseline\n")
            write("Generated/catalog.swift", "generated baseline\n")
            write("Deleted.swift", "delete me\n")
            git("add", ".")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "baseline")
            write("Authored file.swift", "staged change\n")
            git("add", "Authored file.swift")
            write("Authored file.swift", "unstaged change\n")
            write("Generated/catalog.swift", "generated new value\n")
            write("New.swift", "untracked\n")
            (root / "Deleted.swift").unlink()
            before = git("status", "--porcelain=v1", "-z")
            output = read("--working-tree")
            self.assertIn("1 generated files", output)
            self.assertIn('"Generated/catalog.swift"', output)
            self.assertNotIn("+generated new value", output)
            self.assertIn("+unstaged change", output)
            self.assertIn("-delete me", output)
            self.assertIn('authored "New.swift"', output)
            self.assertIn("+generated new value", read("--working-tree", "--generated"))
            staged = read("--staged", "--paths", "Authored file.swift")
            self.assertIn("+staged change", staged)
            self.assertNotIn("unstaged change", staged)
            self.assertNotIn("diff --git", read("--stat", "--working-tree"))
            self.assertEqual(before, git("status", "--porcelain=v1", "-z"))
            # Literal pathspecs prevent a filename from expanding into other files.
            write("[special].swift", "old\n")
            git("add", "[special].swift")
            write("[special].swift", "literal new\n")
            self.assertIn("+literal new", read("--paths", "[special].swift"))
            git("mv", "Generated/catalog.swift", "Moved.swift")
            moved = read("--staged", "--paths", "Generated/catalog.swift", "Moved.swift")
            self.assertIn("1 authored, 1 generated files", moved)
            self.assertIn("+generated baseline", moved)
            self.assertNotIn("-generated baseline", moved)
            expanded = read("--staged", "--generated", "--paths", "Generated/catalog.swift", "Moved.swift")
            self.assertIn("-generated baseline", expanded)
            (root / "Generated/binary.bin").write_bytes(bytes(range(256)))
            git("add", "Generated/binary.bin")
            binary = read("--staged", "--paths", "Generated/binary.bin")
            self.assertIn("+- --", binary)
            self.assertNotIn("Binary files", binary)
            for bad in ("../outside", "Generated", "/tmp/outside"):
                with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                    read("--paths", bad)
