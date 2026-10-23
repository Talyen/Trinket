#!/usr/bin/env python3

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path

from script_test_support import ROOT, ScriptRegressionTestCase, load_script, run_captured

BRIEF = load_script("agent_context_brief", "agent-brief.py")

class AgentContextTests(ScriptRegressionTestCase):
    def test_task_base_scope_keeps_committed_and_dirty_rename_deletion_endpoints(self) -> None:
        from internal.change_routing import classify, collect_paths
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(directory, ('Scripts/build-inputs.env', 'Scripts/config/ui-tests.tsv'))
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=root)
            git('init', '-q', '-b', 'main')
            for name in ('old name.py', 'removed.py', 'dirty.py'):
                (root / name).write_text('original\n')
            api = 'Packages/TrinketCore/Sources/TrinketCore/Probe.swift'
            (root / api).parent.mkdir(parents=True)
            (root / api).write_text('struct Probe {}\n')
            git('add', '.')
            git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'base')
            git('checkout', '-qb', 'codex/task')
            git('mv', 'old name.py', 'committed name.py')
            (root / 'removed.py').unlink()
            (root / api).write_text('public struct Probe {}\n')
            git('add', '-u')
            git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'task')
            git('mv', 'committed name.py', 'staged name.py')
            (root / 'dirty.py').write_text('unstaged\n')
            (root / 'untracked.py').write_text('new\n')
            expected = [api, 'committed name.py', 'dirty.py', 'old name.py', 'removed.py', 'staged name.py', 'untracked.py']
            self.assertEqual(collect_paths(None, root, base='main'), expected)
            self.assertIn('.agents/skills/architect/SKILL.md', classify(expected, root, base='main').skills)
            with self.assertRaises(subprocess.CalledProcessError):
                collect_paths(None, root, base='missing-base')

    def test_voyage_and_labyrinth_focus_preserves_progression_rules_and_broad_discovery(self) -> None:
        for concern in ('voyage', 'labyrinth'):
            command = subprocess.check_output(['bash', 'Scripts/agent-context.sh', '--task', concern, '--read-command'], cwd=ROOT, text=True)
            arguments = shlex.split(command)
            result = run_captured(arguments, cwd=ROOT, expected=0)
            for invariant in ('Reward arithmetic saturates', 'Saved IDs stay stable',
                              'requires a current playable', 'Shop offers are pinned',
                              'Mystery opening pins', 'Defeat and retreat XP'):
                self.assertIn(invariant, result.stdout)
            self.assertNotIn('Corruption gives', result.stdout)
            self.assertNotIn('Homestead collection and build/upgrade', result.stdout)
            route = subprocess.check_output(['bash', 'Scripts/agent-context.sh', '--task', concern], cwd=ROOT, text=True)
            self.assertIn('  Docs/AgentContext/persistence-progression.md\n', route)
            if concern == 'voyage':
                self.assertIn('Voyage encounters use run-and-node identities', result.stdout)

    def test_task_focus_preserves_safeguards_and_full_explicit_verification_scope(self) -> None:
        from internal.agent_tasks import select_task
        self.assertEqual(select_task(ROOT, 'tooling')['id'], 'tooling')
        task = select_task(ROOT, 'cloud')
        paths = [*task['sources'], 'Packages/BattleEngine/Sources/BattleEngine/State/BattleState.swift']
        plain = self.route(*paths)
        focused = self.brief('--task', 'cloud', '--paths', *paths)
        start = focused.index('Concern focus:')
        end = focused.index('Ownership and integration', start)
        without_focus = focused[:start] + focused[end:]
        read_start = without_focus.index('Suggested initial reads (')
        read_end = without_focus.index('Source owners', read_start)
        stripped = without_focus[:read_start] + without_focus[read_end:]
        for reference in task['contracts']:
            self.assertEqual(focused.count('  ' + reference + '\n'), 1)
            plain = plain.replace('  ' + reference + '\n', '')
        self.assertEqual(stripped, plain)
        self.assertIn('persistence-storage.md#reconciliation', focused)
        automatic = self.brief('--task', 'cloud')
        handoff = lambda text: next(line for line in text.splitlines() if './Scripts/handoff.sh' in line)
        self.assertEqual(handoff(automatic), handoff(self.route(*task['sources'])))
        for query in ('missing-concern', 'battle'):
            result = run_captured([str(ROOT / 'Scripts/agent-context.sh'), '--task', query], cwd=ROOT)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('matches:', result.stderr)

    def test_concern_read_command_executes_and_preserves_shared_shop_constraints(self) -> None:
        output = subprocess.check_output([str(ROOT / 'Scripts/agent-context.sh'), '--task', 'shop'], cwd=ROOT, text=True)
        command = next(line.strip() for line in output.splitlines() if 'python3 Scripts/agent-read.py' in line)
        result = run_captured(shlex.split(command), cwd=ROOT, expected=0)
        for invariant in ('Shop offers are pinned', 'Empty Shops prepare stock', 'Voyage encounters use'):
            self.assertIn(invariant, result.stdout)
        self.assertNotIn('Corruption gives', result.stdout)

    def test_inline_guidance_preserves_cross_owner_safeguards_and_explicit_scope(self) -> None:
        path = 'Packages/BattleEngine/Sources/BattleEngine/State/BattleState.swift'
        for flags in (['--read', '--task', 'shop', '--paths', path],
                      ['--task', 'shop', '--paths', path, '--read']):
            output = subprocess.check_output([str(ROOT / 'Scripts/agent-context.sh'), *flags], cwd=ROOT, text=True)
            for invariant in ('Shop offers are pinned', 'generator rather than advance', 'Packages/BattleEngine/AGENTS.md:'):
                self.assertIn(invariant, output)
            self.assertIn('--paths ' + path, output)
            self.assertNotIn('--paths --read', output)
            self.assertNotIn('Suggested initial reads', output)
        # File-scoped work also reads local safeguards without an indexed concern.
        output = subprocess.check_output([str(ROOT / 'Scripts/agent-context.sh'), '--read', '--paths', path], cwd=ROOT, text=True)
        self.assertIn('Packages/BattleEngine/AGENTS.md:', output)
        self.assertNotIn('Shop offers are pinned', output)


    def brief(self, *arguments: str) -> str:
        # Routing matrices exercise the real CLI parser and renderer without a
        # fresh interpreter per row; shell/env/Git boundaries retain CLI tests.
        output = StringIO()
        with redirect_stdout(output):
            result = BRIEF.main(list(arguments), root=ROOT)
        self.assertEqual(result, 0, output.getvalue())
        return output.getvalue()

    def route(self, *paths: str) -> str:
        return self.brief('--agent', '--paths', *paths)

    def test_agent_context_guidance_by_owner(self) -> None:
        cases = (
            ('Raw Assets/Art/example.png', ["'Raw Assets/Art/example.png'"], []),
            ('Packages/TrinketAppState/Sources/TrinketAppState/Play/PlayBattleCoordinator+Launch.swift', ['Docs/AgentContext/battle-runtime.md'], ['Route metadata']),
            ('Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/Feedback/BattleFeedbackLane.swift', ['Docs/AgentContext/battle-runtime.md'], ['apple-design/SKILL.md']),
            ('Packages/BattleEngine/Sources/BattleEngine/State/BattleState.swift', ['Docs/AgentContext/battle-engine.md'], []),
            ('Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/GlassButtons.swift', ['.agents/skills/apple-design/SKILL.md'], ['Docs/AgentContext/swiftui-features.md']),
            ('Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Artwork/PreparedArtworkCache.swift', ['Docs/AgentContext/swiftui-features.md', 'Docs/AgentContext/ui-performance.md'], []),
            ('Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/DesignSystemTests.swift', [], ['apple-design/SKILL.md']),
            ('Packages/TrinketAppState/Sources/TrinketAppState/Audio/MusicPlayer.swift', ['Docs/AgentContext/audio.md'], ['Docs/AgentContext/battle']),
            ('project.yml', ['Docs/AgentContext/content-and-manifests.md'], []),
            ('Scripts/check-docs.py', [], ['Ownership and integration']),
            ('TrinketUITests/Smoke/SmokeShellTests.swift', [], ['apple-design/SKILL.md', '.agents/knowledge/patterns/']),
            ('Packages/BattleEngine/Package.swift', ['.agents/knowledge/patterns/module-dag-containment.md'], []),
            ('Docs/Platform/Architecture.md', [], []),
        )
        for path, required, excluded in cases:
            with self.subTest(path=path):
                output = self.route(path)
                for text in required:
                    self.assertIn(text, output)
                for text in excluded:
                    self.assertNotIn(text, output)

    def test_scope_normalization_preserves_package_verification(self) -> None:
        relative = "Packages/BattleEngine/Sources/BattleEngine/State/BattleState.swift"
        command = [str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--paths"]
        expected = subprocess.check_output([*command, relative], cwd=ROOT, text=True)
        for path in (str(ROOT / relative), "./" + relative, "Packages/../" + relative):
            self.assertEqual(subprocess.check_output([*command, path], cwd=ROOT, text=True), expected)
        for path in (str(ROOT.parent / "outside.swift"), "../outside.swift", "Packages", ""):
            result = run_captured([*command, path], cwd=ROOT)
            self.assertNotEqual(result.returncode, 0, path)
        deleted = subprocess.check_output([*command, str(ROOT / relative.replace("BattleState", "Deleted"))], cwd=ROOT, text=True)
        self.assertIn("./Scripts/test-package.sh BattleEngine", deleted)


    def test_file_brief_reads_ownership_and_keeps_behavior_depth_on_demand(self) -> None:
        path = 'Packages/TrinketPersistence/Sources/TrinketPersistence/Encounters/ShopPurchaseApplier.swift'
        output = self.brief('--read', '--paths', path)
        guidance = output.split('Initial guidance (complete reads;', 1)[1]
        self.assertIn('persistence.md:', guidance)
        self.assertNotIn('Shop offers are pinned', guidance)
        self.assertIn('persistence-progression.md', output)
        expanded = self.brief('--read', '--full', '--paths', path)
        self.assertIn('Shop offers are pinned', expanded)
        self.assertIn('node Scripts/agent-worktree.mjs integrate', output)

    def test_leaf_renames_keep_owner_contracts_and_compact_safeguards(self) -> None:
        from internal.change_routing import classify
        for owner in ('Packages/BattleEngine/Sources/BattleEngine/',
                      'Packages/TrinketPersistence/Sources/TrinketPersistence/',
                      'Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/'):
            with self.subTest(owner=owner):
                before = classify([owner + 'Existing.swift'])
                after = classify([owner + 'Renamed.swift'])
                self.assertEqual(before.cards, after.cards)
                self.assertEqual(before.guides, after.guides)
        for path in ('Packages/BattleEngine/Sources/BattleEngine/ManaEmpowermentBudget.swift',
                     'Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore+Roster.swift',
                     'Trinket/Features/Play/PlayMap/StageSelectModifierCaption.swift'):
            output = self.brief('--status', '--read', '--paths', path)
            self.assertLess(len(output.split()), 650, path)
            self.assertIn('AGENTS.md:', output)
            self.assertIn('Ownership', output)
        engine = self.brief('--read', '--paths', 'Packages/BattleEngine/Sources/BattleEngine/ManaEmpowermentBudget.swift')
        self.assertIn('copy the generator rather than advance live RNG', engine)

    def test_directive_skill_does_not_route_ordinary_rationale_comments(self) -> None:
        from internal.change_routing import classify
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(directory, ('Scripts/build-inputs.env', 'Scripts/config/ui-tests.tsv'))
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            fixture = root / 'Probe.swift'
            for source, expected in (
                ('// Preserve ordering across suspension.\nstruct Probe {}\n', False),
                ('/// Documents the public invariant.\npublic struct Probe {}\n', False),
                ('// swiftlint:disable type_body_length - cohesive owner\nstruct Probe {}\n', True),
                ('// Concurrency-Safety: immutable storage\nstruct Probe {}\n', True),
                ('// UIStyleCheck: allow - content art\nstruct Probe {}\n', True),
            ):
                with self.subTest(source=source):
                    fixture.write_text(source)
                    self.assertEqual('.agents/skills/doc-budget/SKILL.md' in classify(['Probe.swift'], root).skills, expected)


    def test_shared_encounters_and_rewards_keep_visual_guidance(self) -> None:
        for relative_path in (
            "Shared/Encounters/EncounterItemTile.swift",
            "Shared/Encounters/EncounterReadingShell.swift",
            "Shared/Rewards/RewardRevealShell.swift",
            "Shared/Rewards/RewardRevealSequenceState.swift",
            "Shared/Cards/ItemArtwork.swift",
        ):
            with self.subTest(path=relative_path):
                path = "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/" + relative_path
                output = self.route(path)
                self.assertIn("Docs/AgentContext/swiftui-features.md", output)
                self.assertIn(".agents/skills/apple-design/SKILL.md", output)
                self.assertIn("Packages/TrinketFeatureSupport/AGENTS.md", output)


    def test_agent_context_requires_explicit_scope(self) -> None:
        result = run_captured([str(ROOT / "Scripts" / "agent-context.sh"), "--agent"], cwd=ROOT)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires --paths", result.stderr)

    def test_file_scoped_commands_reject_directories(self) -> None:
        for script, flags in (("agent-context.sh", []), ("handoff.sh", ["--dry-run", "--isolate"])):
            with self.subTest(script=script):
                result = run_captured([str(ROOT / "Scripts" / script), *flags, "--paths", "Scripts"], cwd=ROOT)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("individual files", result.stderr)

    def test_agent_context_caps_accidental_working_tree_scope(self) -> None:
        with tempfile.TemporaryDirectory(
            dir=ROOT, prefix=".agent-context-cap-"
        ) as probe_directory:
            probe = Path(probe_directory) / "untracked-probe.txt"
            probe.write_text("working-tree cap probe\n", encoding="utf-8")
            result = run_captured([str(ROOT / "Scripts" / "agent-context.sh"), "--agent", "--working-tree"], cwd=ROOT, env={**os.environ, "TRINKET_MAX_WORKING_TREE_PATHS": "0"})
        self.assertEqual(result.returncode, 3)
        self.assertIn("use explicit --paths or --allow-broad-scope", result.stderr)

    def test_clean_working_tree_briefing_with_status(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(ROOT / "Scripts", root / "Scripts")
            shutil.copy2(ROOT / ".gitignore", root / ".gitignore")
            env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
            subprocess.run(["git", "init", "-q"], cwd=root, env=env, check=True)
            subprocess.run(["git", "add", "Scripts", ".gitignore"], cwd=root, env=env, check=True)
            subprocess.run(
                ["git", "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "-c", "core.hooksPath=/dev/null", "commit", "-qm", "baseline"],
                cwd=root, env=env, check=True,
            )
            for flags in ([], ["--full", "--allow-broad-scope"]):
                with self.subTest(flags=flags):
                    result = run_captured(["/bin/bash", str(root / "Scripts/agent-context.sh"), "--agent", "--status", "--working-tree", *flags], cwd=root, env=env, expected=0)
                    self.assertIn("Workspace status: 0 dirty entries", result.stdout)
                    self.assertIn("Agent context (working tree, 0):", result.stdout)
                    self.assertIn("./Scripts/handoff.sh --isolate --quiet --working-tree", result.stdout)

    def test_compact_and_full_share_required_guidance_and_safety(self) -> None:
        paths = [
            "Trinket/App/HiddenTabPrewarm.swift",
            "Packages/TrinketContent/Sources/TrinketContent/Generated/ArtCatalog.generated.swift",
            "Packages/BattleEngine/Sources/BattleEngine/State/BattleState.swift",
        ]
        compact, full = [
            self.brief(*flags, "--paths", *paths) for flags in ([], ["--full"])
        ]
        for expected in (
            "AGENTS.md", "Docs/AgentContext/ui-performance.md",
            "Docs/AgentContext/battle-engine.md", "Generated/processed paths (do not hand-edit)",
            "./Scripts/handoff.sh --isolate --quiet --paths",
        ):
            self.assertIn(expected, compact)
            self.assertIn(expected, full)
        for expanded in ("Plan detail", "Authored paths"):
            self.assertNotIn(expanded, compact)
            self.assertIn(expanded, full)
        self.assertNotIn("(none)", compact)

    def test_performance_details_are_focused_but_discoverable(self) -> None:
        for path, required in (
            ("Trinket/Features/Play/Shop/ShopEncounterView.swift", False),
            ("Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Artwork/PreparedArtwork.swift", True),
            ("Trinket/App/TrinketApp.swift", True),
            ("Trinket/Features/Collection/CollectionView.swift", True),
        ):
            with self.subTest(path=path):
                output = self.brief('--paths', path)
                self.assertEqual("Docs/AgentContext/ui-performance.md" in output, required)
        general = (ROOT / "Docs/AgentContext/swiftui-features.md").read_text()
        self.assertIn("[UI performance](ui-performance.md)", general)
        self.assertIn("first-screen artwork pins", general)

    def test_large_explicit_scope_still_prints_a_runnable_command(self) -> None:
        paths = [f"Docs/example {index}.md" for index in range(10)]
        output = subprocess.check_output(
            [str(ROOT / "Scripts/agent-context.sh"), "--paths", *paths], cwd=ROOT, text=True,
        )
        import shlex
        command = next(line.strip() for line in output.splitlines() if "./Scripts/handoff.sh" in line)
        self.assertEqual(shlex.split(command), ["./Scripts/handoff.sh", "--isolate", "--quiet", "--paths", *paths])


    def test_agent_context_routes_each_semantic_owner_to_one_required_card(self) -> None:
        cases = (
            (
                "Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift",
                "Docs/AgentContext/persistence.md",
            ),
            (
                "ContentManifest/abilities.tsv",
                "Docs/AgentContext/content-and-manifests.md",
            ),
        )
        for path, expected_card in cases:
            with self.subTest(path=path):
                output = self.route(path)
                self.assertIn(expected_card, output)
                for _, other_card in cases:
                    if other_card != expected_card:
                        self.assertNotIn(other_card, output)


    def test_status_briefing_preserves_scope_and_rename_endpoints(self) -> None:
        status = load_script("agent_status", "internal/agent_status.py")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=root, env=env)
            git("init", "-q")
            for name in ("Packages/A/Old.swift", "Scripts/mixed name.py", "Scripts/deleted.py"):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("original\n")
            git("add", ".")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                "-c", "core.hooksPath=/dev/null", "commit", "-qm", "baseline")
            (root / "Packages/B").mkdir()
            git("mv", "Packages/A/Old.swift", "Packages/B/New.swift")
            mixed = root / "Scripts/mixed name.py"
            mixed.write_text("staged\n")
            git("add", "Scripts/mixed name.py")
            mixed.write_text("unstaged\n")
            (root / "Scripts/deleted.py").unlink()
            (root / "Scripts/new\nfile.py").write_text("untracked\n")
            entries = status.changes(root)
            self.assertEqual({entry.status for entry in entries}, {"R ", "MM", " D", "??"})
            for endpoint in ("Packages/A/Old.swift", "Packages/B/New.swift"):
                brief = status.briefing(root, [endpoint])
                self.assertIn("Packages/A/Old.swift -> Packages/B/New.swift", brief)
                self.assertIn("Packages/A: 1", brief)
                self.assertIn("Packages/B: 1", brief)
                self.assertIn("1 dirty entries; 3 outside supplied paths", brief)
                self.assertNotIn('MM ', brief)
            brief = status.briefing(root, ["Scripts/mixed name.py", "Scripts/deleted.py", "Scripts/new\nfile.py"])
            self.assertIn('MM "Scripts/mixed name.py"', brief)
            self.assertIn(' D Scripts/deleted.py', brief)
            self.assertIn('?? "Scripts/new\\nfile.py"', brief)
            self.assertIn("(supplied paths are clean)", status.briefing(root, ["absent.py"]))
            shutil.copytree(ROOT / "Scripts", root / "Scripts", dirs_exist_ok=True)
            command = [str(root / "Scripts/agent-context.sh"), "--paths", "Scripts/mixed name.py"]
            plain = subprocess.check_output(command, text=True)
            detailed = subprocess.check_output([command[0], "--status", *command[1:]], text=True)
            self.assertNotIn("Workspace status:", plain)
            self.assertIn('MM "Scripts/mixed name.py"', detailed)
            self.assertTrue(detailed.endswith(plain))


if __name__ == "__main__":
    unittest.main()
