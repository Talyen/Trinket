#!/usr/bin/env python3

from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/internal/agent_references.py',
    'Scripts/internal/agent_tasks.py',
    'Scripts/config/agent-tasks.json',
    'Scripts/agent-context.sh',
    'Scripts/change-classification.sh',
    'Scripts/internal/agent_status.py',
    'Scripts/lib/classification-plan.sh',
    'Scripts/lib/smoke-classes.sh',
)


import os
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from script_test_support import ROOT, ScriptRegressionTestCase, load_script

class AgentContextTests(ScriptRegressionTestCase):
    def test_voyage_and_labyrinth_focus_preserves_progression_rules_and_broad_discovery(self) -> None:
        for concern in ('voyage', 'labyrinth'):
            command = subprocess.check_output(['bash', 'Scripts/agent-context.sh', '--task', concern, '--read-command'], cwd=ROOT, text=True)
            chat = f'progression-focus-{concern}-{os.getpid()}'
            arguments = shlex.split(command)
            result = subprocess.run([*arguments[:2], '--chat', chat, *arguments[2:]], cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            from internal.agent_references import session_receipt
            self.addCleanup(session_receipt(chat, ROOT).unlink, missing_ok=True)
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
        task = select_task(ROOT, 'cloud')
        paths = [*task['sources'], 'Packages/BattleEngine/Sources/BattleEngine/State/BattleState.swift']
        plain = self.route(*paths)
        focused = subprocess.check_output([str(ROOT / 'Scripts/agent-context.sh'), '--task', 'cloud', '--paths', *paths], cwd=ROOT, text=True)
        start = focused.index('Concern focus:')
        end = focused.index('Ownership and integration', start)
        without_focus = focused[:start] + focused[end:]
        read_start = without_focus.index('Suggested initial reads (')
        read_end = without_focus.index('Discovery:', read_start)
        stripped = without_focus[:read_start] + without_focus[read_end:]
        for reference in task['contracts']:
            self.assertEqual(focused.count('  ' + reference + '\n'), 1)
            plain = plain.replace('  ' + reference + '\n', '')
        self.assertEqual(stripped, plain)
        self.assertIn('persistence-storage.md#reconciliation', focused)
        automatic = subprocess.check_output([str(ROOT / 'Scripts/agent-context.sh'), '--task', 'cloud'], cwd=ROOT, text=True)
        handoff = lambda text: next(line for line in text.splitlines() if './Scripts/handoff.sh' in line)
        self.assertEqual(handoff(automatic), handoff(self.route(*task['sources'])))
        for query in ('missing-concern', 'battle'):
            result = subprocess.run([str(ROOT / 'Scripts/agent-context.sh'), '--task', query], cwd=ROOT, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('matches:', result.stderr)

    def test_concern_read_command_executes_and_preserves_shared_shop_constraints(self) -> None:
        from internal.agent_references import read_receipt, session_receipt
        chat = 'batch-guidance-' + str(os.getpid())
        output = subprocess.check_output([str(ROOT / 'Scripts/agent-context.sh'), '--task', 'shop'], cwd=ROOT, text=True)
        command = next(line.strip() for line in output.splitlines() if 'Scripts/agent-session.py' in line)
        arguments = shlex.split(command)
        self.assertNotIn('AGENTS.md', arguments)
        result = subprocess.run([*arguments[:2], '--chat', chat, *arguments[2:]], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Shop offers are pinned', result.stdout)
        self.assertIn('Empty Shops prepare stock', result.stdout)
        self.assertIn('Voyage encounters use', result.stdout)
        self.assertNotIn('Corruption gives', result.stdout)
        receipt = session_receipt(chat, ROOT)
        self.addCleanup(receipt.unlink, missing_ok=True)
        reads = read_receipt(receipt, chat, ROOT)['reads']
        self.assertIn('Docs/AgentContext/persistence-progression.md#noncombat-completion', reads)
        leaf = 'Packages/TrinketPersistence/Sources/TrinketPersistence/Encounters/ShopPurchaseApplier.swift'
        hub = 'Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift'
        for paths in ((leaf, hub), (hub, leaf)):
            route = self.route(*paths)
            self.assertIn('persistence-progression.md\n', route)
            self.assertNotIn('persistence-progression.md#', route)

    def test_receipt_rerouting_annotates_reads_without_hiding_safeguards_or_changing_verification(self) -> None:
        path = 'Packages/BattleEngine/Sources/BattleEngine/ManaEmpowermentBudget.swift'
        with tempfile.TemporaryDirectory() as directory:
            receipt = str(Path(directory) / 'receipt.json')
            flags = ['--receipt', receipt, '--chat', 'route-test']
            subprocess.run(['python3', 'Scripts/agent-read.py', 'AGENTS.md', *flags],
                           cwd=ROOT, capture_output=True, check=True)
            output = subprocess.check_output([str(ROOT / 'Scripts/agent-context.sh'), *flags, '--paths', path], cwd=ROOT, text=True)
            plain = self.route(path)
            self.assertIn('AGENTS.md [already read; unchanged]', output)
            self.assertIn('battle-engine.md [read if applicable]', output)
            stripped = output.replace(' [already read; unchanged]', '').replace(' [read if applicable]', '')
            self.assertEqual(plain, stripped)
            changed_chat = subprocess.run([str(ROOT / 'Scripts/agent-context.sh'), '--receipt', receipt,
                                          '--chat', 'fresh-chat', '--paths', path], cwd=ROOT, capture_output=True, text=True)
            self.assertNotEqual(changed_chat.returncode, 0)
            self.assertIn('another chat', changed_chat.stderr)

    def test_focused_action_and_storage_sections_keep_shared_contracts_and_broad_hubs(self) -> None:
        engine = 'Packages/BattleEngine/Sources/BattleEngine/'
        persistence = 'Packages/TrinketPersistence/Sources/TrinketPersistence/'
        cases = (
            (engine + 'ManaEmpowermentBudget.swift', 'battle-actions', {'shared-action-invariants', 'card-preparations', 'action-identity-and-selected-outcomes', 'mana-payments-and-cadence', 'card-assessment'}),
            (engine + 'Cards/BattleCardCombatEngine+OpeningHand.swift', 'battle-actions', {'shared-action-invariants', 'hand-contract', 'turn-ordering'}),
            (persistence + 'PlayerSaveStore+Roster.swift', 'persistence-storage', {'save-compatibility', 'durable-acceptance-and-recovery', 'schema-and-sanitization'}),
        )
        for path, card, expected in cases:
            with self.subTest(path=path):
                output = self.route(path)
                prefix = f'Docs/AgentContext/{card}.md#'
                actual = {line.strip().removeprefix(prefix) for line in output.splitlines() if line.strip().startswith(prefix)}
                self.assertEqual(actual, expected)
                for section in actual:
                    result = subprocess.run(['python3', 'Scripts/agent-read.py', prefix + section], cwd=ROOT, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
        for leaf, hub, card in (
            (engine + 'ManaEmpowermentBudget.swift', engine + 'State/BattleState.swift', 'battle-actions'),
            (persistence + 'PlayerSaveStore+Roster.swift', persistence + 'PlayerSaveStore.swift', 'persistence-storage'),
        ):
            for paths in ((leaf, hub), (hub, leaf)):
                output = self.route(*paths)
                self.assertIn(f'{card}.md\n', output)
                self.assertNotIn(f'{card}.md#', output)

    def test_optional_fingerprints_cover_guides_and_cards_without_changing_the_handoff(self) -> None:
        import hashlib
        path = 'Packages/BattleEngine/Sources/BattleEngine/ManaEmpowermentBudget.swift'
        command = [str(ROOT / 'Scripts/agent-context.sh'), '--fingerprints', '--paths', path]
        output = subprocess.check_output(command, cwd=ROOT, text=True)
        plain = self.route(path)
        for reference in ('AGENTS.md', 'Docs/AgentContext/battle-actions.md#shared-action-invariants'):
            digest = hashlib.sha256((ROOT / reference.partition('#')[0]).read_bytes()).hexdigest()
            self.assertIn(f'{reference} sha256:{digest}', output)
        self.assertNotIn('Reference fingerprints', plain)
        handoff = lambda text: next(line for line in text.splitlines() if './Scripts/handoff.sh' in line)
        self.assertEqual(handoff(plain), handoff(output))

    def route(self, *paths):
        return subprocess.check_output(
            [str(ROOT / 'Scripts/agent-context.sh'), '--agent', '--paths', *paths], cwd=ROOT, text=True,
        )

    def test_agent_context_guidance_by_owner(self) -> None:
        cases = (
            ('Raw Assets/Art/example.png', ['Raw\\ Assets/Art/example.png'], []),
            ('Packages/TrinketAppState/Sources/TrinketAppState/Play/PlayBattleLaunch.swift', ['Docs/AgentContext/battle-runtime.md'], ['Route metadata']),
            ('Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/Feedback/BattleFeedbackLane.swift', ['Docs/AgentContext/battle-runtime.md'], ['apple-design/SKILL.md']),
            ('Packages/BattleEngine/Sources/BattleEngine/State/BattleState.swift', ['Docs/AgentContext/battle-engine.md'], []),
            ('Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/GlassButtons.swift', ['.agents/skills/apple-design/SKILL.md'], ['Docs/AgentContext/swiftui-features.md']),
            ('Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Artwork/PreparedArtworkCache.swift', ['Docs/AgentContext/swiftui-features.md'], []),
            ('Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/DesignSystemTests.swift', [], ['apple-design/SKILL.md']),
            ('Packages/TrinketAppState/Sources/TrinketAppState/Audio/MusicPlayer.swift', ['Docs/AgentContext/audio.md'], ['Docs/AgentContext/battle']),
            ('project.yml', ['Docs/AgentContext/content-and-manifests.md'], []),
            ('Scripts/check-docs.py', [], ['Ownership and integration']),
            ('TrinketUITests/Smoke/SmokeShellTests.swift', [], ['apple-design/SKILL.md']),
            ('Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Artwork/PreparedArtworkCache.swift', ['.agents/knowledge/patterns/artwork-working-set.md'], []),
            ('Packages/BattleEngine/Package.swift', ['.agents/knowledge/patterns/module-dag-containment.md'], []),
            ('Docs/Platform/Architecture.md', ['.agents/knowledge/patterns/architecture-deferred-seams.md'], []),
            ('TrinketUITests/Smoke/SmokeShellTests.swift', [], ['.agents/knowledge/patterns/']),
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
            result = subprocess.run([*command, path], cwd=ROOT, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, path)
        deleted = subprocess.check_output([*command, str(ROOT / relative.replace("BattleState", "Deleted"))], cwd=ROOT, text=True)
        self.assertIn("./Scripts/test-package.sh BattleEngine", deleted)

    def test_focused_contracts_keep_unknown_and_cross_concern_paths_conservative(self) -> None:
        engine = "Packages/BattleEngine/Sources/BattleEngine/"
        persistence = "Packages/TrinketPersistence/Sources/TrinketPersistence/"
        cases = (
            ([engine + "Damage/DamagePipelineOffenseSteps.swift"], {"battle-damage"}),
            ([engine + "Triggers/CombatTriggerEngine+Damage.swift"], {"battle-damage"}),
            ([engine + "Triggers/CombatTriggerEngine+Dodge.swift"], {"battle-damage"}),
            ([engine + "Triggers/CombatTriggerEngine+BlockAndDefense.swift"], {"battle-damage"}),
            ([engine + "Turns/BattleTurnEngine+Resolution.swift"], {"battle-damage"}),
            ([engine + "Triggers/CombatTriggerEngine+Unknown.swift"], {"battle-damage", "battle-actions", "battle-healing"}),
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
                self.assertIn("python3 Scripts/agent-search.py", output)
                references = output.split("Behavior references", 1)[1].split("Skills", 1)[0].split("Memory", 1)[0].split("Discovery", 1)[0]
                self.assertTrue(all(f"/{name}.md" in references for name in expected))
                self.assertNotIn("/battle-engine.md", references)
                self.assertNotIn("/persistence.md", references)

    def test_directive_skill_does_not_route_ordinary_rationale_comments(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "Probe.swift"
            for source, expected in (
                ("// Preserve ordering across suspension.\nstruct Probe {}\n", False),
                ("/* Platform workaround. */\nstruct Probe {}\n", False),
                ("/// Documents the public invariant.\npublic struct Probe {}\n", False),
                ("// swiftlint:disable type_body_length - cohesive owner\nstruct Probe {}\n", True),
                ("// Concurrency-Safety: immutable storage\nstruct Probe {}\n", True),
                ("// UIStyleCheck: allow - content art\nstruct Probe {}\n", True),
            ):
                with self.subTest(source=source):
                    fixture.write_text(source)
                    result = subprocess.run(
                        ["bash", "-c", 'source Scripts/change-classification.sh; trinket_path_needs_doc_budget "$1"',
                         "bash", str(fixture)], cwd=ROOT, capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 0 if expected else 1, result.stderr)

    def test_runtime_contracts_follow_concerns_and_keep_shared_paths_conservative(self) -> None:
        feature = "Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/"
        app = "Packages/TrinketAppState/Sources/TrinketAppState/Play/"
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
            (["Packages/TrinketAppState/Sources/TrinketAppState/App/AppState.swift"], both),
            (["Trinket/App/TrinketApp.swift"], both),
            ([engine + "Runtime/BattleRuntime.swift"], both),
            ([engine + "Runtime/BattleRuntimeDependencies.swift"], both),
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
                    references = [line.strip() for line in output.splitlines() if f"/{name}.md" in line]
                    self.assertEqual(len(references), len(set(references)))
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
                    result = subprocess.run(
                        ["/bin/bash", str(root / "Scripts/agent-context.sh"), "--agent", "--status",
                         "--working-tree", *flags],
                        cwd=root, env=env, capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
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
            subprocess.check_output(
                [str(ROOT / "Scripts/agent-context.sh"), *flags, "--paths", *paths],
                cwd=ROOT, text=True,
            ) for flags in ([], ["--full"])
        ]
        for expected in (
            "AGENTS.md", "Docs/AgentContext/ui-performance.md",
            "Docs/AgentContext/battle-engine.md", "Generated/processed paths (do not hand-edit)",
            "./Scripts/handoff.sh --isolate --quiet --paths",
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
            ("Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Artwork/PreparedArtwork.swift", True),
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


    def test_leaf_sections_include_lifecycle_and_mixed_hubs_restore_broad_reference(self) -> None:
        feature = 'Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/'
        def route(*paths):
            return subprocess.check_output([str(ROOT / 'Scripts/agent-context.sh'), '--paths', *paths], cwd=ROOT, text=True)
        output = route(feature + 'Features/Feedback/CombatFeedbackRasterHost.swift')
        for section in ['display-lifetime', 'display-work-lifecycle', 'floating-combat-feedback']:
            self.assertIn('battle-presentation.md#' + section, output)
        self.assertNotIn('battle-launch.md', output)
        for paths in [(feature + 'Features/Feedback/CombatFeedbackRasterHost.swift', feature + 'State/BattleSession.swift'),
                      (feature + 'State/BattleSession.swift', feature + 'Features/Feedback/CombatFeedbackRasterHost.swift')]:
            output = route(*paths)
            self.assertIn('battle-presentation.md\n', output)
            self.assertNotIn('battle-presentation.md#', output)


    def test_content_guidance_routes_shared_safeguards_and_only_relevant_sections(self) -> None:
        cases = {
            "Packages/TrinketCore/Sources/TrinketCore/Effect.swift": set(),
            "Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityCatalog+Basic.swift": {"abilities"},
            "ContentManifest/talents.tsv": {"manifests"},
            "ArtManifest/art.tsv": {"media-assets"},
            "project.yml": {"project-generation"},
            "Scripts/internal/content/trigger_families/damage.json": {"trigger-schemas", "generation-tooling"},
        }
        prefix = "Docs/AgentContext/content-and-manifests.md#"
        for path, sections in cases.items():
            with self.subTest(path=path):
                output = subprocess.check_output([str(ROOT / "Scripts/agent-context.sh"), "--paths", path],
                                                 cwd=ROOT, text=True)
                actual = {line.strip().removeprefix(prefix) for line in output.splitlines()
                          if line.strip().startswith(prefix)}
                self.assertEqual(actual, sections | {"shared-safeguards"})
                self.assertNotIn("content-and-manifests.md\n", output)


if __name__ == "__main__":
    unittest.main()
