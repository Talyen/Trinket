#!/usr/bin/env python3

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from script_test_support import ROOT, ScriptRegressionTestCase, load_script

class AgentContextTests(ScriptRegressionTestCase):
    def test_scope_normalization_preserves_package_verification(self) -> None:
        relative = "Packages/BattleEngine/Sources/BattleEngine/State/BattleState.swift"
        command = [str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--paths"]
        expected = subprocess.check_output([*command, relative], cwd=ROOT, text=True)
        for path in (str(ROOT / relative), "./" + relative, "Packages/../" + relative):
            self.assertEqual(subprocess.check_output([*command, path], cwd=ROOT, text=True), expected)
        for path in (str(ROOT.parent / "outside.swift"), "../outside.swift", "Packages", ""):
            result = subprocess.run([*command, path], cwd=ROOT, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, path)
        deleted = subprocess.check_output([*command, str(ROOT / relative.replace("BattleState", "Deleted"))], cwd=ROOT, text=True)
        self.assertIn("./Scripts/test-package.sh BattleEngine", deleted)

    def test_focused_contracts_keep_unknown_and_cross_concern_paths_conservative(self) -> None:
        engine = "Packages/BattleEngine/Sources/BattleEngine/"
        persistence = "Packages/TrinketPersistence/Sources/TrinketPersistence/"
        cases = (
            ([engine + "Damage/DamagePipelineResolutionSteps.swift"], {"battle-damage"}),
            ([engine + "EffectHandlers/TimedDebuffHandlers.swift"], {"battle-damage"}),
            ([engine + "Healing/HealingEngine.swift"], {"battle-healing"}),
            ([engine + "State/BattleState.swift"], {"battle-damage", "battle-actions", "battle-healing"}),
            ([engine + "Damage/Steps.swift", engine + "BattleHand.swift"], {"battle-damage", "battle-actions"}),
            ([persistence + "Progression/StageCompletion.swift"], {"persistence-progression"}),
            ([persistence + "Progression/BattleLoot.swift"], {"persistence-progression"}),
            ([persistence + "Encounters/MysteryOfferPersistence.swift"], {"persistence-progression"}),
            ([persistence + "Inventory/StoredInventoryItem.swift"], {"persistence-storage", "persistence-progression"}),
            ([persistence + "PlayerSaveGraph/PlayerSaveRoot.swift"], {"persistence-storage"}),
            ([persistence + "PlayerSaveStore.swift"], {"persistence-storage", "persistence-progression"}),
        )
        details = {"battle-damage", "battle-actions", "battle-healing", "persistence-storage", "persistence-progression"}
        for paths, expected in cases:
            with self.subTest(paths=paths):
                output = subprocess.check_output(
                    [str(ROOT / "Scripts/agent-context.sh"), "--paths", *paths], cwd=ROOT, text=True,
                )
                self.assertEqual({name for name in details if f"/{name}.md" in output}, expected)
                self.assertIn("/battle-engine.md" if paths[0].startswith(engine) else "/persistence.md", output)
                self.assertIn("Search: python3 Scripts/agent-search.py", output)

    def test_runtime_contracts_follow_concerns_and_keep_shared_paths_conservative(self) -> None:
        feature = "Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/"
        app = "Packages/TrinketAppState/Sources/TrinketAppState/State/"
        engine = "Packages/BattleEngine/Sources/BattleEngine/"
        presentation = feature + "Features/BattleAbilityCardView.swift"
        launch = feature + "State/BattleSession+Progression.swift"
        both = {"battle-launch", "battle-presentation"}
        cases = (
            ([presentation], {"battle-presentation"}),
            ([feature + "State/Feedback/CombatFeedbackPresenter.swift"], {"battle-presentation"}),
            ([feature + "State/Feedback/BattleFeedbackLane.swift"], {"battle-presentation"}),
            ([feature + "Support/Performance/BattlePerformanceScenarioDriver.swift"], both),
            ([feature + "State/BattleSession+Transitions.swift"], {"battle-presentation"}),
            ([launch], {"battle-launch"}),
            ([app + "PlaySession+BattleLaunch.swift"], {"battle-launch"}),
            ([app + "PlaySession+BattleCompletion.swift"], {"battle-launch"}),
            ([feature + "State/BattleSession.swift"], both),
            ([feature + "State/BattleSession+Runtime.swift"], both),
            ([feature + "Features/BattleView.swift"], both),
            ([feature + "Features/Outcome/VictoryView.swift"], both),
            ([feature + "Features/UnknownView.swift"], both),
            ([feature + "State/Unknown.swift"], both),
            ([app + "AppState.swift"], both),
            (["Trinket/App/TrinketApp.swift"], both),
            ([engine + "BattleRuntime.swift"], both),
            ([engine + "BattleRuntimeDependencies.swift"], both),
            ([presentation, launch], both),
        )
        for paths, expected in cases:
            with self.subTest(paths=paths):
                output = subprocess.check_output(
                    [str(ROOT / "Scripts/agent-context.sh"), "--paths", *paths], cwd=ROOT, text=True,
                )
                self.assertIn("/battle-runtime.md", output)
                self.assertEqual({name for name in both if f"/{name}.md" in output}, expected)
                for name in expected:
                    self.assertEqual(output.count(f"/{name}.md"), 1)
                if paths[0].startswith(engine):
                    for unrelated in ("battle-damage", "battle-actions", "battle-healing"):
                        self.assertNotIn(f"/{unrelated}.md", output)
        plans = []
        for path in (presentation, launch, feature + "State/BattleSession.swift"):
            plan = subprocess.check_output(
                [str(ROOT / "Scripts/handoff.sh"), "--isolate", "--dry-run", "--paths", path],
                cwd=ROOT, text=True,
            )
            self.assertIn("./Scripts/test-package.sh TrinketBattleFeature", plan)
            plans.append(plan.replace(path, "<changed-file>"))
        self.assertEqual(plans[0], plans[1])
        self.assertEqual(plans[0], plans[2])

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
                output = subprocess.check_output(
                    [str(ROOT / "Scripts/agent-context.sh"), "--agent", "--paths", path],
                    cwd=ROOT, text=True,
                )
                self.assertIn("Docs/AgentContext/swiftui-features.md", output)
                self.assertIn(".agents/skills/apple-design/SKILL.md", output)
                self.assertIn("Packages/TrinketFeatureSupport/AGENTS.md", output)

    def test_agent_context_shell_quotes_paths_with_spaces(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Raw Assets/Art/example.png",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(r"Raw\ Assets/Art/example.png", result.stdout)

    def test_agent_context_requires_explicit_scope(self) -> None:
        result = subprocess.run(
            [str(ROOT / "Scripts" / "agent-context.sh"), "--agent"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires --paths", result.stderr)

    def test_file_scoped_commands_reject_directories(self) -> None:
        for script, flags in (("agent-context.sh", []), ("handoff.sh", ["--dry-run", "--isolate"])):
            with self.subTest(script=script):
                result = subprocess.run(
                    [str(ROOT / "Scripts" / script), *flags, "--paths", "Scripts"],
                    cwd=ROOT, capture_output=True, text=True,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("individual files", result.stderr)

    def test_agent_context_caps_accidental_working_tree_scope(self) -> None:
        with tempfile.TemporaryDirectory(
            dir=ROOT, prefix=".agent-context-cap-"
        ) as probe_directory:
            probe = Path(probe_directory) / "untracked-probe.txt"
            probe.write_text("working-tree cap probe\n", encoding="utf-8")
            result = subprocess.run(
                [str(ROOT / "Scripts" / "agent-context.sh"), "--agent", "--working-tree"],
                cwd=ROOT,
                env={**os.environ, "TRINKET_MAX_WORKING_TREE_PATHS": "0"},
                capture_output=True,
                text=True,
                check=False,
            )
        self.assertEqual(result.returncode, 3)
        self.assertIn("use explicit --paths or --allow-broad-scope", result.stderr)

    def test_compact_and_full_share_required_guidance_and_safety(self) -> None:
        paths = [
            "Trinket/App/HiddenTabPrewarm.swift",
            "Packages/TrinketContent/Sources/TrinketContent/Generated/ArtCatalog.generated.swift",
            "Packages/BattleEngine/Sources/BattleEngine/State/BattleState.swift",
        ]
        compact, full = [
            subprocess.check_output(
                [str(ROOT / "Scripts/agent-context.sh"), *flags, "--paths", *paths],
                cwd=ROOT, text=True,
            ) for flags in ([], ["--full"])
        ]
        for expected in (
            "AGENTS.md", "Docs/AgentContext/ui-performance.md",
            "Docs/AgentContext/battle-engine.md", "Generated/processed paths (do not hand-edit)",
            "./Scripts/handoff.sh --isolate --paths",
        ):
            self.assertIn(expected, compact)
            self.assertIn(expected, full)
        for expanded in ("Route metadata", "Plan detail", "Authored paths"):
            self.assertNotIn(expanded, compact)
            self.assertIn(expanded, full)
        self.assertNotIn("(none)", compact)

    def test_performance_details_are_focused_but_discoverable(self) -> None:
        for path, required in (
            ("Trinket/Features/Play/Shop/ShopEncounterView.swift", False),
            ("Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtwork.swift", True),
            ("Trinket/App/TrinketApp.swift", True),
            ("Trinket/Features/Collection/CollectionView.swift", True),
        ):
            with self.subTest(path=path):
                output = subprocess.check_output(
                    [str(ROOT / "Scripts/agent-context.sh"), "--paths", path], cwd=ROOT, text=True,
                )
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
        self.assertEqual(shlex.split(command), ["./Scripts/handoff.sh", "--isolate", "--paths", *paths])

    def test_agent_context_routes_app_state_to_battle_card(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketAppState/Sources/TrinketAppState/Play/PlayBattleLaunch.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Docs/AgentContext/battle-runtime.md", result.stdout)
        self.assertNotIn("Route metadata", result.stdout)

    def test_agent_context_routes_battle_state_to_focused_card_without_design_skill(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/Feedback/BattleFeedbackLane.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Docs/AgentContext/battle-runtime.md", result.stdout)
        self.assertNotIn("apple-design/SKILL.md", result.stdout)

    def test_agent_context_routes_engine_to_engine_card(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/BattleEngine/Sources/BattleEngine/State/BattleState.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Docs/AgentContext/battle-engine.md", result.stdout)

    def test_agent_context_routes_design_system_to_apple_design(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/Modifiers.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(".agents/skills/apple-design/SKILL.md", result.stdout)
        self.assertNotIn("Docs/AgentContext/swiftui-features.md", result.stdout)

    def test_agent_context_routes_prepared_artwork_to_swiftui_features(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Docs/AgentContext/swiftui-features.md", result.stdout)

    def test_agent_context_keeps_design_skill_off_design_system_tests(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/DesignSystemTests.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("apple-design/SKILL.md", result.stdout)

    def test_agent_context_routes_audio_without_battle_context(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketAppState/Sources/TrinketAppState/Audio/MusicPlayer.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Docs/AgentContext/audio.md", result.stdout)
        self.assertNotIn("Docs/AgentContext/battle", result.stdout)

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
            (
                "Scripts/check-docs.py",
                "Docs/AgentContext/ci-and-project-generation.md",
            ),
        )
        for path, expected_card in cases:
            with self.subTest(path=path):
                result = subprocess.run(
                    [
                        str(ROOT / "Scripts" / "agent-context.sh"),
                        "--agent",
                        "--paths",
                        path,
                    ],
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(expected_card, result.stdout)
                for _, other_card in cases:
                    if other_card != expected_card:
                        self.assertNotIn(other_card, result.stdout)
                self.assertNotIn("Route metadata", result.stdout)

    def test_agent_context_does_not_attach_design_skill_to_ui_tests(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "TrinketUITests/Smoke/SmokeShellTests.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("apple-design/SKILL.md", result.stdout)

    def test_agent_context_surfaces_artwork_memory_for_prepared_artwork(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            ".agents/knowledge/patterns/artwork-working-set.md", result.stdout
        )

    def test_agent_context_surfaces_dag_memory_for_package_manifest(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/BattleEngine/Package.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            ".agents/knowledge/patterns/module-dag-containment.md", result.stdout
        )

    def test_agent_context_surfaces_deferred_seams_for_architecture_doc(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Docs/Platform/Architecture.md",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            ".agents/knowledge/patterns/architecture-deferred-seams.md",
            result.stdout,
        )

    def test_agent_context_keeps_memory_quiet_for_unrelated_paths(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "TrinketUITests/Smoke/SmokeShellTests.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(".agents/knowledge/patterns/", result.stdout)

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
