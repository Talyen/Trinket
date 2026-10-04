import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

struct ModeProgressionToolingTests {
    @Test func `mode progression trackers build non empty steps`() {
        let campaign = ModeProgressionTracker.campaign()
        let spire = ModeProgressionTracker.spire()
        let labyrinth = ModeProgressionTracker.labyrinth()

        let campaignStages = GameContent.chapters.flatMap(\.stages).filter(\.encounter.isCombat)
        #expect(campaign.steps.map(\.id) == campaignStages.map { "campaign-\($0.chapterID)-\($0.id)" })
        #expect(labyrinth.steps.map(\.stepIndex) == Array(1 ... 10))
        #expect(labyrinth.steps.dropLast().allSatisfy { !$0.isBoss })
        #expect(labyrinth.steps.last?.isBoss == true)
        #expect(ModeProgressionTracker.labyrinth(maxDepth: 0).steps.isEmpty)
        #expect(ModeProgressionTracker.labyrinth(maxDepth: -1).steps.isEmpty)
        let expectedSpireSteps = GameContent.spires.reduce(0) { total, spireDefinition in
            total + GameContent.spireFloors(for: spireDefinition.id).count
        }
        #expect(spire.steps.count == expectedSpireSteps)
        #expect(Set(spire.steps.map(\.id)).count == spire.steps.count)
    }

    @Test func `interleaving player controller gains XP and levels up`() {
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
            isBoss: false,
        )

        for _ in 0 ..< 10 {
            controller.recordOutcome(step: step, won: true)
        }

        #expect(controller.state.heroLevel > initialLevel)
        #expect(controller.state.totalBattles == 10)
        #expect(controller.state.battlesWon == 10)
    }

    @Test(arguments: [
        (0, 8, 0, 5, HotspotStatus.overtuned),
        (0, 0, 8, 5, .smooth),
        (1, 0, 8, 5, .smooth),
        (0, 8, 0, Int.max, .overtuned),
    ])
    func `hotspot analyzer classifies decided envelopes`(
        wins: Int, defeats: Int, timeouts: Int, level: Int, expected: HotspotStatus,
    ) throws {
        let step = ModeProgressionStep(
            id: "step-1",
            mode: .campaign,
            containerID: "c1",
            containerTitle: "Chapter 1",
            stepIndex: 1,
            displayTitle: "Stage 1",
            enemyID: "goblin",
            enemyLevel: 5,
            isBoss: false,
        )

        let records = (0 ..< (wins + defeats + timeouts)).map { index in
            ProgressionBattleRecord(
                step: step,
                playerLevel: level,
                enemyLevel: level,
                seed: UInt64(index),
                result: BattleSimResult(
                    outcome: (index < wins) ? .victory : .defeat,
                    rounds: 10,
                    actions: 20,
                    timedOut: index >= wins + defeats,
                    partyHPRemainingFraction: 0,
                    enemyHPRemainingFraction: 0.8,
                ),
            )
        }

        let summaries = HotspotAnalyzer.analyze(records: records)
        let summary = try #require(summaries.first)
        let decided = wins + defeats
        #expect(summary.status == expected)
        #expect(summary.battles == decided)
        #expect(summary.wins == wins)
        #expect(summary.winRate == (decided == 0 ? 0 : Double(wins) / Double(decided)))
        let confidence = BalanceStatsAggregator.wilson(wins: wins, battles: decided)
        #expect(summary.wilsonLow == confidence.low)
        #expect(summary.wilsonHigh == confidence.high)
        #expect(summary.averagePlayerLevel == (decided == 0 ? 0 : Double(level)))
        #expect(summary.averageEnemyLevel == (decided == 0 ? 0 : Double(level)))
    }

    @Test func `progression matchup spends legal talents at current level`() {
        let controller = InterleavingPlayerController(
            initialState: PlayerProgressionState(heroLevel: 20, companionLevel: 20),
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
            isBoss: false,
        )
        let matchup = controller.makeMatchup(for: step, seed: 11)
        let budget = CombatantProgression.at(level: 20).totalTalentPoints
        #expect(matchup.context.heroTalentIDs.count == budget)
        #expect(matchup.context.companionTalentIDs.count == budget)
    }

    @Test func `progression early campaign matchup uses starter gear`() {
        let controller = InterleavingPlayerController(
            initialState: PlayerProgressionState(heroLevel: 2, companionLevel: 2),
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
            isBoss: false,
        )
        let matchup = controller.makeMatchup(for: step, seed: 11)
        #expect(matchup.context.heroTalentIDs.count == 1)
        #expect(matchup.context.companionTalentIDs.count == 1)
        #expect(matchup.context.heroAffixIDs.count == 1)
        #expect(matchup.context.companionAffixIDs.count == 1)
    }

    @Test func `progression spire matchup is on level`() throws {
        let controller = InterleavingPlayerController(
            initialState: PlayerProgressionState(heroLevel: 20, companionLevel: 20),
        )
        let step = ModeProgressionStep(
            id: "spire-step",
            mode: .spire,
            containerID: "resonanceHall",
            containerTitle: "Resonance Hall",
            stepIndex: 10,
            displayTitle: "Resonance Hall Floor 10",
            enemyID: "the_forge_golem",
            enemyLevel: 20,
            isBoss: true,
        )
        let matchup = controller.makeMatchup(for: step, seed: 11)
        let budget = CombatantProgression.at(level: 20).totalTalentPoints
        #expect(matchup.context.heroTalentIDs.count == budget)
        #expect(matchup.context.companionTalentIDs.count == budget)
        #expect(!(matchup.context.heroAffixIDs.isEmpty))
        let enemy = try #require(GameContent.enemy(matching: "the_forge_golem"))
        let scaledEnemy = CombatantLevelScaler.scale(enemy: enemy, level: 20)
        #expect(matchup.enemy.maxHealth == scaledEnemy.maxHealth)
        #expect(matchup.enemyFaction == enemy.faction)
    }

    @Test func `player and enemy scaling continue beyond talent completion`() throws {
        let wizard = try #require(GameContent.hero(matching: "wizard"))
        let enemy = try #require(GameContent.enemy(matching: "slime"))

        let playerAt45 = CombatantLevelScaler.scale(combatant: wizard, level: 45)
        #expect(playerAt45.maxHealth == wizard.maxHealth + 44)
        #expect(playerAt45.maxMana == wizard.maxMana + 22)

        let enemyAt44 = CombatantLevelScaler.scale(enemy: enemy, level: 44)
        let enemyAt45 = CombatantLevelScaler.scale(enemy: enemy, level: 45)
        #expect(enemyAt45.maxHealth > enemyAt44.maxHealth)
        #expect(
            EnemyPowerCurve.rawDamagePercent(level: 45, isBoss: enemy.isBoss)
                > EnemyPowerCurve.rawDamagePercent(level: 44, isBoss: enemy.isBoss),
        )
    }

    @Test(arguments: [(SimulationGameMode.campaign, 17), (.spire, 20), (.labyrinth, 16)])
    func `low party uses mode minimum`(mode: SimulationGameMode, expectedLevel: Int) throws {
        let controller = InterleavingPlayerController(
            initialState: PlayerProgressionState(heroLevel: 3, companionLevel: 2),
        )
        let step = ModeProgressionStep(
            id: "mode-floor", mode: mode, containerID: "container", containerTitle: "Container",
            stepIndex: 1, displayTitle: "Encounter", enemyID: "goblin", enemyLevel: 20, isBoss: false,
        )
        let matchup = controller.makeMatchup(for: step, seed: 1772)
        let enemy = try #require(GameContent.enemy(matching: step.enemyID))
        #expect(controller.encounterLevel(for: step) == expectedLevel)
        #expect(matchup.enemy.maxHealth == CombatantLevelScaler.scale(enemy: enemy, level: expectedLevel).maxHealth)
    }

    @Test func `mixed party uses truncated average like live play`() {
        let controller = InterleavingPlayerController(
            initialState: PlayerProgressionState(heroLevel: 15, companionLevel: 16),
        )
        let step = ModeProgressionStep(
            id: "mixed-party", mode: .campaign, containerID: "container", containerTitle: "Container",
            stepIndex: 1, displayTitle: "Encounter", enemyID: "goblin", enemyLevel: 20, isBoss: false,
        )
        #expect(controller.encounterLevel(for: step) == 18)
    }

    @Test func `overleveled spire win awards no XP`() {
        let step = ModeProgressionStep(
            id: "spire-step",
            mode: .spire,
            containerID: "ironVein",
            containerTitle: "Iron Vein",
            stepIndex: 1,
            displayTitle: "Iron Vein Floor 1",
            enemyID: "goblin",
            enemyLevel: 2,
            isBoss: false,
        )
        let controller = InterleavingPlayerController(
            campaignTracker: .init(steps: []),
            spireTracker: .init(steps: [step]),
            labyrinthTracker: .init(steps: []),
            initialState: PlayerProgressionState(heroLevel: 20, companionLevel: 20),
        )
        #expect(controller.selectNextStep() == step)
        controller.recordOutcome(step: step, won: true)
        #expect(controller.state.heroLevel == 20)
        #expect(controller.state.companionLevel == 20)
        #expect(controller.state.heroXP == 0)
        #expect(controller.state.companionXP == 0)
        #expect(controller.isComplete)
        #expect(controller.selectNextStep() == nil)
    }

    @Test func `mode progression report formatter renders summary`() {
        let records = [ProgressionBattleRecord(
            step: ModeProgressionStep(
                id: "unfinished", mode: .campaign, containerID: "c1", containerTitle: "Chapter 1",
                stepIndex: 1, displayTitle: "Stage 1", enemyID: "goblin", enemyLevel: 5, isBoss: false,
            ),
            playerLevel: 5, enemyLevel: 5, seed: 1,
            result: BattleSimResult(
                outcome: .defeat, rounds: 100, actions: 200, timedOut: true,
                partyHPRemainingFraction: 0.5, enemyHPRemainingFraction: 0.8,
            ),
        )]
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(mode: .modeProgression, battlesPerTier: 2, jobs: 1),
            policyID: "greedy-v1",
            progressionHotspots: HotspotAnalyzer.analyze(records: records),
            progressionRecords: records,
            progressionPlayerStates: [
                PlayerProgressionState(heroLevel: 4, companionLevel: 3),
                PlayerProgressionState(heroLevel: 5, companionLevel: 4),
            ],
            elapsedSeconds: 1,
        )
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("# Multi-Mode Progression & Hotspot Balance Report"))
        #expect(markdown.contains("Progression Summary"))
        #expect(markdown.contains("**Simulated Runs**: 2"))
        #expect(markdown.contains("**Total Battles Simulated**: 1"))
        #expect(markdown.contains("**Decided Battles**: 0"))
        #expect(markdown.contains("**Unfinished Battles**: 1"))
        #expect(markdown.contains("| 0 | n/a | n/a | n/a | n/a | n/a | NO DECIDED SAMPLES |"))
    }

    @Test func `mode all markdown includes progression`() {
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(mode: .all, battlesPerTier: 1, tiers: [.early], jobs: 1),
            policyID: "greedy-v1",
            progressionPlayerStates: [PlayerProgressionState()],
            elapsedSeconds: 0,
        )
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("# Balance Sweep Report"))
        #expect(markdown.contains("# Multi-Mode Progression & Hotspot Balance Report"))
    }
}
