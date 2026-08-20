import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

struct BattleSimulatorSweepReportTests {
    @Test func parallelIdentityMatchesSequentialOutcomes() {
        let sequential = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 6,
                seed: 11,
                tiers: [.early],
                jobs: 1,
                enemyIDs: ["living_armor"]
            )
        )
        let parallel = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 6,
                seed: 11,
                tiers: [.early],
                jobs: 4,
                enemyIDs: ["living_armor"]
            )
        )
        #expect(sequential.records.map(\.result) == parallel.records.map(\.result))
        #expect(sequential.records.map(\.seed) == parallel.records.map(\.seed))
    }

    @Test func abilityContrastProducesLiftRows() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .abilityContrast,
                battlesPerTier: 2,
                seed: 21,
                tiers: [.early],
                jobs: 1,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                enemyIDs: ["living_armor"]
            )
        )
        #expect(report.records.isEmpty)
        #expect(!(report.abilityContrasts.isEmpty))
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("Ability Contrasts"))
    }

    @Test func affixContrastProducesLiftRowsOnMidTier() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .affixContrast,
                battlesPerTier: 2,
                seed: 22,
                tiers: [.middle],
                jobs: 1,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                enemyIDs: ["living_armor"],
                focusIDs: ["keen"]
            )
        )
        #expect(!(report.affixContrasts.isEmpty))
        #expect(report.affixContrasts.contains { $0.baselineKind == .emptySlot })
        #expect(report.affixContrasts.contains { $0.baselineKind == .replacementAffix })
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("Affix Contrasts"))
    }

    @Test func wilsonIntervalContainsPointEstimate() {
        let ci = BalanceStatsAggregator.wilson(wins: 80, battles: 100)
        #expect(ci.low <= 0.80)
        #expect(ci.high >= 0.80)
        #expect(ci.low < ci.high)
    }

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

        // Record wins until level increases
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
        controller.recordOutcome(step: step, won: true)
        #expect(controller.state.heroXP == equalAward
            || controller.state.heroLevel > 20)
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

    @Test func identityQuotasEqualBattlesPerEnemy() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 3,
                seed: 9,
                tiers: [.early],
                jobs: 1,
                enemyIDs: ["living_armor", "mimic"]
            )
        )
        #expect(report.records.count == 6)
        let byEnemy = Dictionary(grouping: report.records, by: \.enemyID)
        #expect(byEnemy["living_armor"]?.count == 3)
        #expect(byEnemy["mimic"]?.count == 3)
    }

    @Test func identityWinRateExcludesTimeouts() {
        let timeout = BattleSimResult(
            outcome: .defeat,
            rounds: 100,
            actions: 500,
            timedOut: true,
            partyHPRemainingFraction: 0.5,
            enemyHPRemainingFraction: 0.5
        )
        let win = BattleSimResult(
            outcome: .victory,
            rounds: 6,
            actions: 10,
            timedOut: false,
            partyHPRemainingFraction: 0.8,
            enemyHPRemainingFraction: 0
        )
        func record(_ result: BattleSimResult, seed: UInt64) -> BalanceBattleRecord {
            BalanceBattleRecord(
                tier: .early,
                heroID: "knight",
                companionID: "bear",
                enemyID: "living_armor",
                isBoss: false,
                heroAbilityIDs: ["bash"],
                companionAbilityIDs: ["swipe"],
                enemyAbilityIDs: ["slash"],
                enemyTraitID: "living_armor_trait",
                affixIDs: [],
                heroAffixIDs: [],
                companionAffixIDs: [],
                heroTalentIDs: [],
                companionTalentIDs: [],
                seed: seed,
                policyID: "greedy-v1",
                result: result
            )
        }
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(mode: .identity, battlesPerTier: 2, tiers: [.early], jobs: 1),
            policyID: "greedy-v1",
            records: [record(timeout, seed: 1), record(win, seed: 2)],
            elapsedSeconds: 0
        )
        let stats = BalanceStatsAggregator.summarize(report: report)[0]
        #expect(stats.timeouts == 1)
        #expect(stats.decidedBattles == 1)
        #expect(stats.wins == 1)
        #expect(stats.heroes.first?.winRate == 1)
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
