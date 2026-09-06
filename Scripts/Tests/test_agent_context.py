#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

from script_test_support import ROOT, ScriptRegressionTestCase, load_script

class AgentContextTests(ScriptRegressionTestCase):
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
            "Packages/BattleEngine/Sources/BattleEngine/BattleState.swift",
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
                "Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/BattleFeedbackLane.swift",
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
                "Packages/BattleEngine/Sources/BattleEngine/BattleState.swift",
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

if __name__ == "__main__":
    unittest.main()
