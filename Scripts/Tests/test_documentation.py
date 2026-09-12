from __future__ import annotations

import contextlib
import io
import json
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

from script_test_support import ROOT, ScriptRegressionTestCase, load_script


class DocumentationTests(ScriptRegressionTestCase):
    def test_ui_registration_requires_actual_unique_matrix_targets(self) -> None:
        checker = load_script("ui_registration", "check-testplan-sync.py")
        original_read = Path.read_text
        workflow = ROOT / ".github/workflows/tests.yml"
        original = workflow.read_text()
        self.assertEqual(checker.testplan_failures(), [])
        cases = [
            ("StarterOnboardingSmokeTests ", "", "smoke matrix mismatch"),
            ("target: BattleFlowUITests", "target: MissingTests # BattleFlowUITests", "exhaustive-ui matrix mismatch"),
            ("target: BattleFlowUITests", "target: BattleFlowUITests BattleFlowUITests", "duplicate classes"),
        ]
        for old, new, message in cases:
            with self.subTest(change=new):
                self.assertIn(old, original)
                def read(path, *args, **kwargs):
                    return original.replace(old, new) if path == workflow else original_read(path, *args, **kwargs)
                with patch.object(Path, "read_text", read):
                    self.assertTrue(any(message in failure for failure in checker.testplan_failures()))

    @classmethod
    def setUpClass(cls) -> None:
        cls.check_docs = load_script("check_docs", "check-docs.py")

    def test_test_scripts_supports_skip_docs(self) -> None:
        text = (ROOT / "Scripts" / "test-scripts.sh").read_text(encoding="utf-8")
        self.assertIn("--skip-docs", text)
        self.assertIn('if [[ "$SKIP_DOCS" != true ]]; then', text)

    def test_handoff_runs_cheap_ci_slices_and_skips_docs_on_final(self) -> None:
        handoff = (ROOT / "Scripts" / "handoff.sh").read_text(encoding="utf-8")
        self.assertIn("run_cheap_ci_slices", handoff)
        self.assertIn("source Scripts/lib/cheap-slices.sh", handoff)
        self.assertIn("trinket_run_cheap_slices", handoff)
        self.assertIn('if [[ "$FINAL" == true ]]; then', handoff)
        self.assertIn("./Scripts/test-scripts.sh --skip-docs", handoff)
        self.assertIn('kind" == docs && "$FINAL" == true', handoff)

    def test_docs_markdown_routes_check_docs(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Docs/Platform/Verification.md",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = [line.strip() for line in result.stdout.splitlines() if line.startswith("  ")]
        self.assertIn("python3 ./Scripts/check-docs.py", plan)
        self.assertIn("./Scripts/check-module-boundaries.sh", plan)
        self.assertIn("./Scripts/check-artwork-budget.sh", plan)

    def test_new_plan_scaffold_creates_lifecycle_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Scripts").mkdir()
            (root / "Docs/Plans").mkdir(parents=True)
            script = root / "Scripts/new-plan.sh"
            shutil.copy2(ROOT / "Scripts/new-plan.sh", script)
            created = subprocess.run([str(script), "Fixture"], cwd=root, capture_output=True, text=True)
            self.assertEqual(created.returncode, 0, created.stderr)
            text = (root / "Docs/Plans/Fixture.md").read_text(encoding="utf-8")
            self.assertIn("type: execution-plan", text)
            self.assertIn("status: active", text)
            self.assertIn("expires:", text)
            self.assertIn("Docs/Plans/Archived/README.md", text)
            self.assertIn("delete this plan", text)

    def test_plan_metadata_requires_lifecycle_fields_and_blocked_reason(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            valid = root / "valid.md"
            valid.write_text(
                "---\n"
                "type: execution-plan\n"
                "status: active\n"
                "created: 2026-08-20\n"
                "updated: 2026-08-20\n"
                "expires: 2026-09-03\n"
                "---\n\n# Plan\n",
                encoding="utf-8",
            )
            metadata, errors = self.check_docs.plan_metadata(valid)
            self.assertEqual(errors, [])
            self.assertEqual(metadata["status"], "active")

            blocked = root / "blocked.md"
            blocked.write_text(valid.read_text(encoding="utf-8").replace("status: active", "status: blocked"), encoding="utf-8")
            _, errors = self.check_docs.plan_metadata(blocked)
            self.assertIn("blocked plans require reason", errors)

    def test_plan_checks_scope_closure_but_preserve_global_validation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            subprocess.run(["git", "init", "-q", str(parent)], check=True)
            (parent / ".gitignore").write_text("export/\n")
            root = parent / "export"
            root.mkdir()
            scripts = root / "Scripts"
            scripts.mkdir()
            for name in ("check-docs.py", "check-plans.py", "check-links.py", "check-testplan-sync.py", "internal/markdown.py"):
                (scripts / name).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, scripts / name)
            for name, content in {
                "Scripts/Reference.md": "Scripts/change-classification.sh",
                "Scripts/change-classification.sh": "",
                "Scripts/config/smoke-classes.txt": "",
                "Smoke.xctestplan": '{"testTargets": []}',
                "FullUI.xctestplan": '{"testTargets": []}',
                ".github/workflows/tests.yml": "",
                "Docs/AgentContext/README.md": "# Context",
                "Docs/Audits/Proposals.md": "# Proposals",
                "README.md": "# Fixture",
            }.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            plan = root / "Docs/Plans/Pending work.md"
            plan.parent.mkdir()
            original = (
                "---\ntype: execution-plan\nstatus: active\n"
                "created: 2000-01-01\nupdated: 2000-01-03\nexpires: 2000-01-02\n"
                "---\n\n# Pending decision\n"
            )
            plan.write_text(original)

            def run(name, *args, status=0, message=""):
                result = subprocess.run([sys.executable, str(scripts / name), *args],
                                        cwd=root, capture_output=True, text=True)
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                self.assertIn(message, result.stdout + result.stderr)
                return result

            for name in ("check-docs.py", "check-plans.py"):
                with self.subTest(checker=name):
                    run(name, message="Warning:")
                    run(name, "--final", status=1, message="active plan remains")
                    run(name, "--final", "--paths", "README.md", message="Warning:")
                    run(name, "--final", "--paths", str(plan), status=1, message="active plan remains")
                    run(name, "--final", "--keep-plan", "--paths", "Docs/Plans/Pending work.md")
                    run(name, "--final", "--paths", "Docs/Plans/Deleted.md")
                    for args in (("--paths",), ("--paths", "Docs"), ("--paths", "../outside.md")):
                        run(name, *args, status=2)
                    plan.write_text(original.replace("status: active", "status: blocked\nreason: Pending decision"))
                    run(name, "--final")
                    plan.write_text(original.replace("status: active", "status: blocked"))
                    run(name, "--paths", "README.md", status=1, message="blocked plans require reason")
                    plan.write_text(original.replace("expires: 2000-01-02\n", ""))
                    run(name, "--paths", "README.md", status=1, message="missing expires")
                    plan.write_text(original.replace("status: active", "status: complete"))
                    run(name, "--paths", "README.md", status=1, message="must be summarized")
                    archive = plan.parent / "Archived" / plan.name
                    archive.parent.mkdir(exist_ok=True)
                    plan.rename(archive)
                    run(name, "--paths", "README.md", status=1, message="completed plan detail belongs in Git history")
                    archive.unlink()
                    parallel = root / ".agents/plans/Parallel.md"
                    parallel.parent.mkdir(parents=True, exist_ok=True)
                    parallel.write_text("# Parallel plan")
                    run(name, "--paths", "README.md", status=1, message="execution plans are allowed only directly")
                    parallel.unlink()
                    plan.write_text(original)

            (root / "Docs/Broken.md").write_text("[missing](missing.md)")
            run("check-docs.py", "--final", "--paths", "README.md", status=1, message="missing.md")
            (root / "Docs/Broken.md").unlink()
            (scripts / "config/smoke-classes.txt").write_text("SHELL=MissingTests")
            run("check-docs.py", "--final", "--paths", "README.md", status=1, message="selectedTests must match")
            self.assertEqual(plan.read_text(), original)

    def test_proposal_evidence_identifier_resolution(self) -> None:
        self.assertTrue(self.check_docs.source_contains_identifier("performBatchMutation"))
        missing = "RemovedProposal" + "EvidenceSymbol"
        self.assertFalse(self.check_docs.source_contains_identifier(missing))

    def test_document_heading_cache_reuses_parsed_targets(self) -> None:
        from unittest.mock import patch
        links = load_script("review_links", "check-links.py")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target.md"
            target.write_text("# Target\n")
            source = root / "source.md"
            source.write_text("[one](target.md#target) [two](target.md#target)\n")
            with patch.object(links, "ROOT", root), patch.object(links, "heading_slugs", wraps=links.heading_slugs) as parse:
                self.assertEqual(links.broken_links([source]), [])
                parse.assert_called_once_with(target.resolve())

    def test_markdown_inventory_excludes_ignored_run_reports(self) -> None:
        paths = self.check_docs.markdown_files()
        self.assertTrue(paths)
        self.assertTrue(all(path.suffix == ".md" for path in paths))
        self.assertFalse(any("BalanceSweepReports" in path.parts for path in paths))

    def test_command_inventory_is_owned_by_reference_not_entry_page(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            scripts.mkdir()
            (scripts / "build.sh").write_text("#!/bin/sh\n")
            (scripts / "README.md").write_text("[Commands](Reference.md)\n")
            reference = scripts / "Reference.md"
            with patch.object(self.check_docs, "ROOT", root):
                self.assertTrue(self.check_docs.script_index_failures())
                reference.write_text("| `./Scripts/build.sh` | Build |\n")
                self.assertEqual(self.check_docs.script_index_failures(), [])
                (scripts / "new-command.sh").write_text("#!/bin/sh\n")
                (scripts / "README.md").write_text("./Scripts/new-command.sh\n")
                failures = self.check_docs.script_index_failures()
                self.assertEqual(len(failures), 1)
                self.assertIn("Scripts/Reference.md", failures[0])
                self.assertIn("Scripts/new-command.sh", failures[0])

    def test_markdown_under_executable_and_manifest_roots_selects_only_docs(self) -> None:
        for path in ("Scripts/README.md", "ContentManifest/README.md", "ArtManifest/README.md"):
            with self.subTest(path=path):
                output = subprocess.check_output(
                    [str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--paths", path], cwd=ROOT, text=True,
                )
                self.assertIn("python3 ./Scripts/check-docs.py", output)
                self.assertNotIn("./Scripts/test-scripts.sh", output)
                self.assertNotIn("./Scripts/generate.sh", output)

    def test_script_families_union_leaf_coverage_and_fall_back_for_shared_inputs(self) -> None:
        selector = load_script("script_test_selection", "script_test_selection.py")
        select = selector.select_tests
        all_tests = select([])
        search = "Scripts/Tests/test_agent_search.py"
        self.assertEqual(select(["Scripts/agent-search.py", "Scripts/README.md"]), [search])
        performance = select(["Scripts/compare-performance.py"])
        self.assertIn("Scripts/Tests/test_exec_wrappers.py", performance)
        self.assertEqual(select(["Scripts/agent-search.py", "Scripts/compare-performance.py"]), sorted([search, *performance]))
        self.assertLess(len(select(["Scripts/check-links.py"])), len(all_tests))
        for shared in ("Scripts/lib/args.sh", "Scripts/test-scripts.sh", "Scripts/new-script.py",
                       "Scripts/Tests/script_test_support.py", ".github/workflows/tests.yml", "project.yml"):
            with self.subTest(shared=shared):
                self.assertEqual(select(["Scripts/agent-search.py", shared]), all_tests)
        with self.assertRaises(ValueError):
            select(["Scripts"])

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
        script_commands = [p for p in planned if p.startswith("./Scripts/test-scripts.sh")]
        self.assertEqual(script_commands, [
            "./Scripts/test-scripts.sh --skip-docs --paths Docs/Platform/Verification.md Scripts/build.sh",
        ])

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
        self.assertIn("./Scripts/test-scripts.sh --paths Scripts/build.sh", planned)
        self.assertFalse(any("--skip-docs" in command for command in planned))
        # Ensure cheap slices still present; docs not separately listed for plain script is OK because test-scripts.sh runs it internally,
        # but the plan must not have duplicate docs entry.
        self.assertEqual(planned.count("python3 ./Scripts/check-docs.py"), 0)

    def test_final_handoff_preview_matches_execution_scope_without_running_docs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            shutil.copytree(ROOT / "Scripts", scripts)
            captured = root / "docs-args.json"
            (scripts / "check-docs.py").write_text(
                'import json, pathlib, sys\n'
                'pathlib.Path("docs-args.json").write_text(json.dumps(sys.argv[1:]))\n'
                'raise SystemExit(91)\n'
            )
            for flags in (["--final"], ["--final", "--keep-plan"]):
                with self.subTest(flags=flags):
                    args = [*flags, "--paths", "Scripts/build.sh", "Docs/Plans/Pending work.md"]
                    preview = subprocess.run([str(scripts / "handoff.sh"), "--dry-run", *args],
                                             capture_output=True, text=True)
                    self.assertEqual(preview.returncode, 0, preview.stdout + preview.stderr)
                    self.assertFalse(captured.exists())
                    command = next(line.strip() for line in preview.stdout.splitlines()
                                   if "python3 ./Scripts/check-docs.py" in line)
                    result = subprocess.run([str(scripts / "handoff.sh"), *args], capture_output=True, text=True)
                    self.assertEqual(result.returncode, 91, result.stdout + result.stderr)
                    expected = [*flags, "--paths", "Docs/Plans/Pending work.md", "Scripts/build.sh"]
                    self.assertEqual(json.loads(captured.read_text()), expected)
                    self.assertEqual(shlex.split(command)[2:], expected)
                    captured.unlink()


    def test_section_reader_preserves_complete_ranges_and_link_anchor_identity(self) -> None:
        reader = load_script("agent_read", "agent-read.py")
        links = load_script("section_links", "check-links.py")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lines = ["# Guide", "Intro", "## Repeat", "Policy", "### Child", "x" * 500,
                     "````markdown", "## Hidden", "```", "[hidden](missing.md)", "~~~~", "````",
                     "Child ending", "## Repeat", "Second", "## Repeat-1", "Third"]
            path = root / "Guide.md"
            path.write_text("\n".join(lines) + "\n")
            def read(target, *flags):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    status = reader.main([target, *flags], root=root)
                self.assertEqual(status, 0)
                return output.getvalue()
            section = read("Guide.md#repeat")
            self.assertIn("Guide.md:3-13 (complete section)", section)
            self.assertIn("1: # Guide", section)
            self.assertIn("6: " + "x" * 500, section)
            self.assertIn("13: Child ending", section)
            self.assertNotIn("14: ## Repeat", section)
            child = read("Guide.md#child")
            self.assertIn("3: ## Repeat", child)
            self.assertIn("5: ### Child", child)
            self.assertNotIn("4: Policy", child)
            outline = read("Guide.md", "--outline")
            self.assertNotIn("#hidden", outline)
            self.assertIn("Guide.md#repeat-1 [14-15]", outline)
            self.assertIn("Guide.md#repeat-1-1 [16-17]", outline)
            self.assertIn("15: Second", read("Guide.md#repeat-1"))
            self.assertIn("17: Third", read("Guide.md"))
            source = root / "Links.md"
            source.write_text("\n".join(f"[section](Guide.md#{slug})" for slug in links.heading_slugs(path)))
            with patch.object(links, "ROOT", root):
                self.assertEqual(links.broken_links([source, path]), [])
            for target in ("Guide.md#absent", "../outside.md", "Guide.swift"):
                with contextlib.redirect_stderr(io.StringIO()) as error, contextlib.redirect_stdout(io.StringIO()) as output:
                    self.assertEqual(reader.main([target], root=root), 2)
                self.assertEqual(output.getvalue(), "")
                self.assertIn("Read failed:", error.getvalue())

    def test_shared_markdown_helper_selects_all_direct_consumers(self) -> None:
        select = load_script("script_test_selection", "script_test_selection.py").select_tests
        expected = ["Scripts/Tests/test_documentation.py"]
        for path in ("Scripts/check-links.py", "Scripts/check-docs.py", "Scripts/check-plans.py",
                     "Scripts/check-testplan-sync.py", "Scripts/agent-read.py", "Scripts/internal/markdown.py"):
            self.assertEqual(select([path]), expected)
        self.assertGreater(len(select(["Scripts/Tests/script_test_support.py"])), len(expected))
