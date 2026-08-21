import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

/// Progression tooling units that run with the default package suite:
/// trackers, player-controller leveling, hotspot classification, and report rendering.
struct ModeProgressionToolingTests {
    @Test func modeProgressionTrackersBuildNonEmptySteps() {
        let campaign = CampaignProgressionTracker()
        let spire = SpireProgressionTracker()
        let labyrinth = LabyrinthProgressionTracker()

        #expect(!(campaign.steps.isEmpty))
        #expect(!(spire.steps.isEmpty))
        #expect(!(labyrinth.steps.isEmpty))
        let expectedSpireSteps = GameContent.spires.reduce(0) { total, spireDefinition in
            total + GameContent.spireFloors(for: spireDefinition.id).count
        }
        #expect(spire.steps.count == expectedSpireSteps)
        #expect(Set(spire.steps.map(\.id)).count == spire.steps.count)
    }

    @Test func interleavingPlayerControllerGainsXPAndLevelsUp() {
        let controller = InterleavingPlayerController()
        let initialLevel = controller.state.heroLevel

        let step = ModeProgressionStep(
            id: "test-step",
            mode: .campaign,
            containerID: "chapter-1",
            containerTitle: "Chapter 1",
            stepIndex: 1,
            displayTitle: "Stage 1-1",
            enemyID: "goblin",
            enemyLevel: 5,
            isBoss: false
        )

        for _ in 0 ..< 10 {
            controller.recordOutcome(step: step, won: true)
        }

        #expect(controller.state.heroLevel > initialLevel)
        #expect(controller.state.totalBattles == 10)
        #expect(controller.state.battlesWon == 10)
    }

    @Test func hotspotAnalyzerClassifiesEnvelopes() throws {
        let step = ModeProgressionStep(
            id: "step-1",
            mode: .campaign,
            containerID: "c1",
            containerTitle: "Chapter 1",
            stepIndex: 1,
            displayTitle: "Stage 1",
            enemyID: "goblin",
            enemyLevel: 5,
            isBoss: false
        )

        let overtunedRecords = (0 ..< 8).map { index in
            ProgressionBattleRecord(
                step: step,
                playerLevel: 5,
                enemyLevel: 5,
                seed: UInt64(index),
                result: BattleSimResult(
                    outcome: .defeat,
                    rounds: 10,
                    actions: 20,
                    timedOut: false,
                    partyHPRemainingFraction: 0,
                    enemyHPRemainingFraction: 0.8
                )
            )
        }

        let summaries = HotspotAnalyzer.analyze(records: overtunedRecords)
        let summary = try #require(summaries.first)
        #expect(summary.status == .overtuned)
        #expect(summary.isFlagged == true)
    }

    @Test func progressionMatchupSpendsLegalTalentsAtCurrentLevel() {
        let controller = InterleavingPlayerController(
            initialState: PlayerProgressionState(heroLevel: 20, companionLevel: 20)
        )
        let step = ModeProgressionStep(
            id: "test-step",
            mode: .campaign,
            containerID: "chapter-1",
            containerTitle: "Chapter 1",
            stepIndex: 1,
            displayTitle: "Stage 1-1",
            enemyID: "living_armor",
            enemyLevel: 20,
            isBoss: false
        )
        let matchup = controller.makeMatchup(for: step, seed: 11)
        let budget = CombatantProgression.at(level: 20).totalTalentPoints
        #expect(matchup.context.heroTalentIDs.count == budget)
        #expect(matchup.context.companionTalentIDs.count == budget)
    }

    @Test func progressionEarlyCampaignMatchupUsesStarterGear() {
        let controller = InterleavingPlayerController(
            initialState: PlayerProgressionState(heroLevel: 2, companionLevel: 2)
        )
        let step = ModeProgressionStep(
            id: "test-step",
            mode: .campaign,
            containerID: "chapter-1",
            containerTitle: "Chapter 1",
            stepIndex: 1,
            displayTitle: "Stage 1-1",
            enemyID: "slime",
            enemyLevel: 1,
            isBoss: false
        )
        let matchup = controller.makeMatchup(for: step, seed: 11)
        #expect(matchup.context.heroTalentIDs.count == 1)
        #expect(matchup.context.companionTalentIDs.count == 1)
        #expect(matchup.context.heroAffixIDs.count == 1)
        #expect(matchup.context.companionAffixIDs.count == 1)
    }

    @Test func progressionSpireMatchupIsOnLevel() throws {
        let controller = InterleavingPlayerController()
        let step = ModeProgressionStep(
            id: "spire-step",
            mode: .spire,
            containerID: "resonanceHall",
            containerTitle: "Resonance Hall",
            stepIndex: 10,
            displayTitle: "Resonance Hall Floor 10",
            enemyID: "the_forge_golem",
            enemyLevel: 20,
            isBoss: true
        )
        let matchup = controller.makeMatchup(for: step, seed: 11)
        #expect(controller.simulatedHeroLevel(for: step) == 20)
        #expect(controller.simulatedCompanionLevel(for: step) == 20)
        let budget = CombatantProgression.at(level: 20).totalTalentPoints
        #expect(matchup.context.heroTalentIDs.count == budget)
        #expect(matchup.context.companionTalentIDs.count == budget)
        #expect(!(matchup.context.heroAffixIDs.isEmpty))
        let enemy = try #require(GameContent.enemy(matching: "the_forge_golem"))
        let scaledEnemy = CombatantLevelScaler.scale(enemy: enemy, level: 20)
        #expect(matchup.enemy.maxHealth == scaledEnemy.maxHealth)
    }

    @Test func spireWinAwardsEqualLevelXPAtSaveLevel() {
        let controller = InterleavingPlayerController(
            initialState: PlayerProgressionState(heroLevel: 20, companionLevel: 20)
        )
        let step = ModeProgressionStep(
            id: "spire-step",
            mode: .spire,
            containerID: "ironVein",
            containerTitle: "Iron Vein",
            stepIndex: 1,
            displayTitle: "Iron Vein Floor 1",
            enemyID: "goblin",
            enemyLevel: 2,
            isBoss: false
        )
        let equalAward = ExperienceScaling.battleAwardWithCatchUp(
            playerLevel: 20,
            enemyLevel: 20,
            highestLevel: 20
        )
        let underleveledEnemyAward = ExperienceScaling.battleAwardWithCatchUp(
            playerLevel: 20,
            enemyLevel: 2,
            highestLevel: 20
        )
        #expect(equalAward != underleveledEnemyAward)
        let expectedHeroProgression = CombatantProgression(
            level: 20,
            currentXP: 0,
            requiredXP: CombatantProgression.requiredXP(forLevel: 20)
        ).addingExperience(equalAward)
        controller.recordOutcome(step: step, won: true)
        #expect(controller.state.heroLevel == expectedHeroProgression.level)
        #expect(controller.state.heroXP == expectedHeroProgression.currentXP)
    }

    @Test func modeProgressionReportFormatterRendersSummary() {
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(mode: .modeProgression, battlesPerTier: 2, jobs: 1),
            policyID: "greedy-v1",
            progressionPlayerStates: [
                PlayerProgressionState(heroLevel: 4, companionLevel: 3),
                PlayerProgressionState(heroLevel: 5, companionLevel: 4),
            ],
            elapsedSeconds: 1
        )
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("# Multi-Mode Progression & Hotspot Balance Report"))
        #expect(markdown.contains("Progression Summary"))
        #expect(markdown.contains("**Simulated Runs**: 2"))
    }

    @Test func modeAllMarkdownIncludesProgression() {
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(mode: .all, battlesPerTier: 1, tiers: [.early], jobs: 1),
            policyID: "greedy-v1",
            progressionPlayerStates: [PlayerProgressionState()],
            elapsedSeconds: 0
        )
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("# Balance Sweep Report"))
        #expect(markdown.contains("# Multi-Mode Progression & Hotspot Balance Report"))
    }
}
