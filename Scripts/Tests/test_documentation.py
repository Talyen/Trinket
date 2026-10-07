from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/internal/output_retention.py',
    'Scripts/lib/output-retention.sh',
    'Scripts/check-docs.py',
    'Scripts/check-links.py',
    'Scripts/check-plans.py',
    'Scripts/check-testplan-sync.py',
    'Scripts/ci-gate.sh',
    'Scripts/config/cheap-slices.txt',
    'Scripts/config/ui-tests.tsv',
    'Scripts/handoff.sh',
    'Scripts/internal/doc_diagnostics.py',
    'Scripts/internal/markdown.py',
    'Scripts/internal/swift_policy.py',
    'Scripts/lib/args.sh',
    'Scripts/lib/cheap-slices.sh',
    'Scripts/lib/gate.sh',
    'Scripts/new-plan.sh',
)


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
    @classmethod
    def setUpClass(cls) -> None:
        cls.check_docs = load_script("check_docs", "check-docs.py")

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
            self.assertNotIn("Archived", text)
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
            metadata, errors = self.check_docs._check_plans.plan_metadata(valid)
            self.assertEqual(errors, [])
            self.assertEqual(metadata["status"], "active")

            blocked = root / "blocked.md"
            blocked.write_text(valid.read_text(encoding="utf-8").replace("status: active", "status: blocked"), encoding="utf-8")
            _, errors = self.check_docs._check_plans.plan_metadata(blocked)
            self.assertIn("blocked plans require reason", errors)
            blocked.write_text(valid.read_text().replace("status: active", "status: active\nstatus: blocked\nreason: pending"))
            _, errors = self.check_docs._check_plans.plan_metadata(blocked)
            self.assertIn("duplicate status", errors)

    def test_plan_checks_scope_closure_but_preserve_global_validation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            subprocess.run(["git", "init", "-q", str(parent)], check=True)
            (parent / ".gitignore").write_text("export/\n")
            root = parent / "export"
            root.mkdir()
            scripts = root / "Scripts"
            scripts.mkdir()
            for name in ("check-docs.py", "check-plans.py", "check-links.py", "check-testplan-sync.py", "internal/markdown.py", "internal/cli.py", "internal/doc_diagnostics.py", "internal/output_retention.py"):
                (scripts / name).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, scripts / name)
            for name, content in {
                "Scripts/Reference.md": "Scripts/change-classification.sh",
                "Scripts/change-classification.sh": "",
                "Scripts/config/ui-tests.tsv": "Smoke|SHELL|SmokeFixture\nFullUI||FullFixture\n",
                "TrinketUITests/Smoke/Fixture.swift": "class SmokeFixture: TrinketUITestCase {}",
                "TrinketUITests/Fixture.swift": "class FullFixture: TrinketUITestCase {}",
                "Smoke.xctestplan": json.dumps({"testTargets": [{"automaticallyIncludesTests": False, "selectedTests": ["SmokeFixture"], "target": {"name": "TrinketUITests"}}]}),
                "FullUI.xctestplan": json.dumps({"testTargets": [{"automaticallyIncludesTests": False, "selectedTests": ["FullFixture"], "target": {"name": "TrinketUITests"}}]}),
                ".github/workflows/tests.yml": "  build:\n      run: check-testplan-sync.py --classes Smoke --classes FullUI\n      command: ./Scripts/test.sh ui --no-build ${{ steps.ui-matrices.outputs.full-targets }}\n      command: ./Scripts/test.sh smoke --no-build ${{ steps.ui-matrices.outputs.smoke-targets }}\n  exhaustive-ui:\n      run: check-testplan-sync.py --classes FullUI\n      command: ./Scripts/test.sh ui --no-build ${{ steps.ui-targets.outputs.targets }}\n",
                "Docs/AgentContext/README.md": "# Context",
                "Docs/Audits/Proposals.md": "# Proposals",
                "README.md": "# Fixture\nA clean pass is valid. Historical label: QuickSmoke.\n",
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
                    run(name, "--paths", "README.md", status=1, message="must be deleted")
                    archive = plan.parent / "Archived" / plan.name
                    archive.parent.mkdir(exist_ok=True)
                    plan.rename(archive)
                    run(name, "--paths", "README.md", status=1, message="execution plans are allowed only directly")
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
            (scripts / "config/ui-tests.tsv").write_text("SHELL=MissingTests")
            run("check-docs.py", "--final", "--paths", "README.md", status=1, message="expected suite|key|class")
            self.assertEqual(plan.read_text(), original)

    def test_proposal_evidence_identifier_resolution(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            scripts = root / "Scripts"
            scripts.mkdir()
            (root / ".gitignore").write_text("Scripts/ignored.py\n")
            (scripts / "tracked.py").write_text("def tracked_evidence(): pass\n")
            subprocess.run(["git", "add", "Scripts/tracked.py"], cwd=root, check=True)
            (scripts / "new.py").write_text("def new_evidence(): pass\n")
            (scripts / "ignored.py").write_text("def ignored_evidence(): pass\n")
            (scripts / "README.md").write_text("Retired: removed_evidence\n")
            with patch.object(self.check_docs, "ROOT", root):
                self.assertTrue(self.check_docs.source_contains_identifier("tracked_evidence"))
                self.assertTrue(self.check_docs.source_contains_identifier("new_evidence"))
                self.assertFalse(self.check_docs.source_contains_identifier("ignored_evidence"))
                self.assertFalse(self.check_docs.source_contains_identifier("removed_evidence"))

    def test_audit_inventory_matches_ownership_table(self) -> None:
        self.assertEqual(self.check_docs.audit_inventory_failures(), [])

    def test_audit_inventory_catches_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            audits = root / "Docs/Audits"
            audits.mkdir(parents=True)
            (audits / "README.md").write_text(
                "# Audits\n\n"
                "## Ownership\n\n"
                "| 01 | [01_PresentAudit.md](01_PresentAudit.md) | Present |\n"
                "| 03 | [03_MissingAudit.md](03_MissingAudit.md) | Missing |\n"
                "| 05 | [05_RetiredAudit.md](05_RetiredAudit.md) | Retired |\n"
                "\n"
                "### Confusable pairs\n\n"
                "| Unlisted elsewhere | [02_UnlistedAudit.md](02_UnlistedAudit.md) |\n"
            )
            (audits / "01_PresentAudit.md").write_text("# 01. Present Audit\n")
            (audits / "02_UnlistedAudit.md").write_text("# Wrong heading\n")
            (audits / "05_RetiredAudit.md").write_text("# 05. Retired Audit\n")
            with patch.object(self.check_docs, "ROOT", root):
                failures = self.check_docs.audit_inventory_failures()
            joined = "\n".join(failures)
            self.assertIn("02_UnlistedAudit.md: guide is not listed", joined)
            self.assertIn("03_MissingAudit.md, which does not exist", joined)
            self.assertIn("reuses retired audit number 05", joined)
            self.assertIn("does not start with '# 02.'", joined)

    def test_plan_marker_detection_reads_front_matter_only(self) -> None:
        check_plans = self.check_docs._check_plans
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            plan = root / "plan.md"
            plan.write_text("---\ntype: execution-plan\nstatus: active\n---\n\n# Plan\n")
            self.assertTrue(check_plans.declares_execution_plan(plan))
            prose = root / "prose.md"
            prose.write_text("# Guide\n\nFront matter uses `type: execution-plan`.\n")
            self.assertFalse(check_plans.declares_execution_plan(prose))
            unfenced = root / "unfenced.md"
            unfenced.write_text("---\nA document starting with a rule.\n")
            self.assertFalse(check_plans.declares_execution_plan(unfenced))
            self.assertFalse(check_plans.declares_execution_plan(root / "missing.md"))

    def test_command_inventory_rejects_stale_rows(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            scripts.mkdir()
            (scripts / "kept.sh").write_text("#!/bin/sh\n")
            (scripts / "Reference.md").write_text(
                "| `./Scripts/kept.sh` | Kept |\n"
                "| `./Scripts/deleted.sh` | Gone |\n"
            )
            with patch.object(self.check_docs, "ROOT", root):
                failures = self.check_docs.script_index_failures()
            self.assertEqual(len(failures), 1)
            self.assertIn("Scripts/deleted.sh", failures[0])
            self.assertIn("does not exist", failures[0])

    def test_links_preserve_encoded_filenames_and_check_heading_destinations(self) -> None:
        links = load_script("review_links", "check-links.py")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target #1.md"
            target.write_text("# Target\n")
            source = root / "source.md"
            source.write_text('[one](target%20%231.md#target) [two](<target %231.md>)\n'
                              '[three](<target %231.md#target> "title") [empty]()\n'
                              '[external](codex://threads/fixture)\n')
            with patch.object(links, "ROOT", root):
                self.assertEqual(links.broken_links([source]), [])
                (root / 'other.md').write_text('# Other\n')
                source.write_text('[missing](target%20%231.md#absent)\n[other](other.md#absent)\n')
                failures = links.broken_links([source])
                self.assertEqual(failures, ['source.md:1: missing heading target #1.md#absent',
                                            'source.md:2: missing heading other.md#absent'])
                from internal.doc_diagnostics import group_failures
                self.assertEqual(len(group_failures(failures)), 2)

    def test_markdown_inventory_preserves_git_filenames_and_excludes_ignored_reports(self) -> None:
        links = load_script("documentation_inventory", "check-links.py")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            (root / ".gitignore").write_text("ignored/\n")
            tracked = root / "règles.md"
            tracked.write_text("# Rules\n")
            subprocess.run(["git", "-C", str(root), "add", tracked.name], check=True)
            untracked = root / "notes with spaces.md"
            untracked.write_text("# Notes\n")
            (root / "ignored").mkdir()
            (root / "ignored/report.md").write_text("# Ignored\n")
            with patch.object(links, "ROOT", root):
                self.assertEqual(set(links.markdown_files()), {tracked, untracked})
                with patch.object(links.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "git")):
                    with self.assertRaises(subprocess.CalledProcessError):
                        links.markdown_files()

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
        search = ["Scripts/Tests/test_agent_callers.py", "Scripts/Tests/test_agent_efficiency.py",
                  "Scripts/Tests/test_agent_investigate.py", "Scripts/Tests/test_agent_search.py"]
        self.assertEqual(select(["Scripts/agent-search.py", "Scripts/README.md"]), search)
        performance = select(["Scripts/compare-performance.py"])
        self.assertIn("Scripts/Tests/test_compare_performance.py", performance)
        self.assertNotIn("Scripts/Tests/test_exec_wrappers.py", performance)
        self.assertEqual(select(["Scripts/agent-search.py", "Scripts/compare-performance.py"]), sorted(set(search + performance)))
        self.assertLess(len(select(["Scripts/check-links.py"])), len(all_tests))
        for shared in ("Scripts/test-scripts.sh", "Scripts/new-script.py",
                       "Scripts/Tests/script_test_support.py", ".github/workflows/tests.yml", "project.yml"):
            with self.subTest(shared=shared):
                self.assertEqual(select(["Scripts/agent-search.py", shared]), all_tests)
        with self.assertRaises(ValueError):
            select(["Scripts"])

    def test_script_families_cover_expanded_leaves_without_full_fallback(self) -> None:
        select = load_script("script_test_selection", "script_test_selection.py").select_tests
        all_tests = select([])
        cases = {
            "Scripts/handoff.sh": {"Scripts/Tests/test_output_retention.py",
                                   "Scripts/Tests/test_ci_path_filter.py",
                                   "Scripts/Tests/test_ci_gate_scripts.py",
                                   "Scripts/Tests/test_ci_handoff_routing.py",
                                   "Scripts/Tests/test_verification_policy.py",
                                   "Scripts/Tests/test_documentation.py",
                                   "Scripts/Tests/test-lib-args.sh"},
            "Scripts/check-unused-assets.py": {"Scripts/Tests/test_check_unused_assets.py"},
            "Scripts/ci-path-filter.py": {"Scripts/Tests/test_ci_path_filter.py", "Scripts/Tests/test_ci_effort.py"},
            "Scripts/balance-sweep.sh": {"Scripts/Tests/test_balance_report_retention.py"},
            "Scripts/test-timing.py": {"Scripts/Tests/test_test_timing.py",
                                       "Scripts/Tests/test_ci_build_scripts.py"},
            "Scripts/run-env.sh": {"Scripts/Tests/test_ci_session_scripts.py",
                                   "Scripts/Tests/test_ci_build_scripts.py",
                                   "Scripts/Tests/test_build_process.py",
                                   "Scripts/Tests/test-run-env.sh"},
            "Scripts/lib/media-assets.sh": {"Scripts/Tests/test_media_asset_scripts.py",
                                            "Scripts/Tests/test_asset_library.py",
                                            "Scripts/Tests/test_ci_build_scripts.py",
                                            "Scripts/Tests/test-asset-hash-sort-locale.sh"},
            "Scripts/Tests/test_agent_search.py": {"Scripts/Tests/test_agent_search.py"},
            "Scripts/lint.sh": {"Scripts/Tests/test_build_artifacts.py",
                                "Scripts/Tests/test_build_process.py",
                                "Scripts/Tests/test_ci_build_scripts.py",
                                "Scripts/Tests/test-lib-args.sh",
                                "Scripts/Tests/test-lib-tempdir.sh"},
            "Scripts/assert-generated-output.sh": {"Scripts/Tests/test_project_generation.py",
                                                   "Scripts/Tests/test_build_process.py",
                                                   "Scripts/Tests/test_ci_build_scripts.py"},
            "Scripts/config/ui-tests.tsv": {"Scripts/Tests/test_project_generation.py",
                                                 "Scripts/Tests/test_ui_registration.py",
                                                 "Scripts/Tests/test_build_process.py",
                                                 "Scripts/Tests/test_ci_build_scripts.py",
                                                 "Scripts/Tests/test_documentation.py"},
        }
        for path, expected in cases.items():
            with self.subTest(path=path):
                selected = select([path])
                self.assertEqual(set(selected), expected)
                self.assertLess(len(selected), len(all_tests))
        # Residual unknowns still run everything (safe default).
        for unknown in ("Scripts/new-script.py", "Scripts/internal/cli.py", "Scripts/test-scripts.sh"):
            with self.subTest(unknown=unknown):
                self.assertEqual(select([unknown]), all_tests)

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
        for hosted in (False, True):
            with self.subTest(hosted=hosted):
                result = subprocess.run(
                    [str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--paths",
                     "Scripts/build.sh", "Docs/Platform/Verification.md"],
                    cwd=ROOT, env=self.verification_environment(hosted=hosted),
                    capture_output=True, text=True, check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                planned = [line.strip() for line in result.stdout.splitlines() if line.startswith("  ")]
                self.assertEqual(planned.count("python3 ./Scripts/check-docs.py"), 1)
                script_commands = [p for p in planned if p.startswith("./Scripts/test-scripts.sh")]
                flag = "--skip-docs" if hosted else "--fast"
                self.assertEqual(script_commands, [
                    f"./Scripts/test-scripts.sh {flag} --paths Docs/Platform/Verification.md Scripts/build.sh",
                ])

    def test_plain_script_scope_still_validates_docs(self) -> None:
        for hosted in (False, True):
            with self.subTest(hosted=hosted):
                result = subprocess.run(
                    [str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--paths", "Scripts/build.sh"],
                    cwd=ROOT, env=self.verification_environment(hosted=hosted),
                    capture_output=True, text=True, check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                planned = [line.strip() for line in result.stdout.splitlines() if line.startswith("  ")]
                flag = "" if hosted else " --fast"
                self.assertIn(f"./Scripts/test-scripts.sh{flag} --paths Scripts/build.sh", planned)
                self.assertFalse(any("--skip-docs" in command for command in planned))
                # Hosted scripts own docs; fast local scripts need one separate docs check.
                self.assertEqual(planned.count("python3 ./Scripts/check-docs.py"), 0 if hosted else 1)

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


    def test_shared_markdown_helper_selects_all_direct_consumers(self) -> None:
        select = load_script("script_test_selection", "script_test_selection.py").select_tests
        expected = ["Scripts/Tests/test_documentation.py"]
        for path in ("Scripts/check-links.py", "Scripts/check-docs.py", "Scripts/check-plans.py",
                     "Scripts/check-testplan-sync.py", "Scripts/internal/markdown.py"):
            self.assertIn("Scripts/Tests/test_documentation.py", select([path]))
        self.assertGreater(len(select(["Scripts/Tests/script_test_support.py"])), len(expected))


    def test_documentation_failures_retain_complete_bounded_report(self) -> None:
        from internal.doc_diagnostics import group_failures, report_failures, render
        failures = [f"Docs/File{i}.md:3: missing link target ../Missing.md" for i in range(100)]
        failures += [f"Other{i}.md: distinct issue {i}" for i in range(25)]
        self.assertEqual(len(group_failures(failures)), 26)
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict("os.environ", {"RESULTS_DIR": directory}), contextlib.redirect_stderr(io.StringIO()) as output:
                report_failures("Failed", failures)
            self.assertLess(len(output.getvalue()), 12000)
            self.assertIn("98 additional locations", output.getvalue())
            self.assertIn("Omitted 6 groups", output.getvalue())
            reports = list(Path(directory).glob("*.json"))
            self.assertEqual(len(reports), 1)
            self.assertEqual(json.loads(reports[0].read_text())["failures"], failures)
            with contextlib.redirect_stderr(io.StringIO()) as expanded:
                self.assertEqual(render(group_failures(failures), offset=20, full=True), 26)
            self.assertIn("distinct issue 24", expanded.getvalue())
