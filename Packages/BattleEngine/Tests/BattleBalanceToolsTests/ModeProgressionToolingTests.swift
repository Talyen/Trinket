import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

struct ModeProgressionToolingTests {
    @Test func `random encounters cannot attribute one enemy's losses to another enemy`() throws {
        let records = ["goblin", "skeleton"].flatMap { enemyID in
            (0 ..< 8).map { sample in
                ProgressionBattleRecord(
                    step: BalanceTestFixtures.step(
                        enemyID: enemyID,
                        enemyLevel: 10,
                    ),
                    playerLevel: 10, enemyLevel: 10, seed: UInt64(sample),
                    result: BalanceTestFixtures.result(
                        outcome: enemyID == "goblin" ? .defeat : .victory,
                        rounds: 10,
                        actions: 40,
                        partyHPRemainingFraction: 0,
                    ),
                )
            }
        }
        let recoveryRecords = records.map { record in
            var recovery = record
            recovery.step.mode = .contract
            recovery.step.id = "recovery-contract"
            return recovery
        }
        let summaries = HotspotAnalyzer.analyze(records: records + recoveryRecords)
        #expect(summaries.count == 2)
        #expect(try #require(summaries.first { $0.step.enemyID == "goblin" }).winRate == 0)
        #expect(try #require(summaries.first { $0.step.enemyID == "skeleton" }).winRate == 1)
        let config = BalanceSweepConfig(mode: .modeProgression)
        let slices = [records, recoveryRecords].map { slice in
            BalanceSweepReport(config: config, policyID: config.policyID, progressionRecords: slice, elapsedSeconds: 0)
        }
        let merged = BalanceSweepReport.merged(slices, config: config, policyID: config.policyID, elapsedSeconds: 0)
        #expect(merged.progressionHotspots == summaries)
        #expect(merged.progressionRecords.count == records.count + recoveryRecords.count)
    }

    @Test func `Spire progression includes floors regardless of party keywords`() throws {
        let holy = try #require(GameContent.spire(id: .aureateChoir))
        let controller = InterleavingPlayerController(
            campaignTracker: .init(steps: []), spireTracker: .spire(spires: [holy]),
            labyrinthTracker: .init(steps: []),
        )
        #expect(!controller.isComplete)
        #expect(controller.selectNextStep()?.containerID == holy.id.rawValue)
    }

    @Test func `Spire combat uses the seeded floor modifier without replacing loadout aligned gear`() throws {
        let hero = try #require(GameContent.hero(matching: "ranger"))
        let companion = try #require(GameContent.companion(matching: "wolf"))
        let spire = try #require(GameContent.spire(id: .ironVein))
        let floor = try #require(GameContent.spireFloor(spireID: spire.id, floor: 1))
        let worldSeed = try #require((UInt64(1) ... 100).first { seed in
            guard let modifier = GameContent.spireModifier(for: floor, worldSeed: seed) else { return false }
            if case .damageDealt = modifier.effect {
                return true
            }
            return false
        })
        let controller = InterleavingPlayerController(
            hero: hero, companion: companion, campaignTracker: .init(steps: []),
            spireTracker: .spire(spires: [spire]), labyrinthTracker: .init(steps: []),
            initialState: PlayerProgressionState(heroLevel: 20, companionLevel: 20), worldSeed: worldSeed, equipmentModel: .tier,
        )
        let step = try #require(controller.selectNextStep())
        let actual = controller.makeMatchup(for: step, seed: 43)
        let enemy = try #require(GameContent.enemy(matching: step.enemyID))
        let expected = SimulationMatchupBuilder.build(
            hero: hero, companion: companion, enemy: enemy, tier: .middle, enemyLevel: step.enemyLevel, enemyPowerProfile: .spire,
            heroLoadout: actual.context.heroLoadout, companionLoadout: actual.context.companionLoadout,
            seed: 43, heroTalents: Set(actual.context.heroTalentIDs), companionTalents: Set(actual.context.companionTalentIDs),
        )
        #expect(actual.enemy.maxHealth == expected.enemy.maxHealth)
        #expect(actual.enemyModifiers.outgoingDamagePercent == expected.enemyModifiers.outgoingDamagePercent)
        #expect(actual.context.heroAffixIDs == expected.context.heroAffixIDs)
        #expect(actual.context.companionAffixIDs == expected.context.companionAffixIDs)
        #expect(actual.context.heroItemBaseIDs == expected.context.heroItemBaseIDs)
        #expect(actual.enemyModifiers.damageDealtBonus[.physical, default: 0]
            == expected.enemyModifiers.damageDealtBonus[.physical, default: 0] + 1)
    }

    @Test func `defeats award existing peak depletion XP without clearing the encounter`() {
        let step = BalanceTestFixtures.step(enemyLevel: 10)
        let controller = InterleavingPlayerController(
            campaignTracker: .init(steps: [step]), spireTracker: .init(steps: []), labyrinthTracker: .init(steps: []),
            initialState: PlayerProgressionState(heroLevel: 10, companionLevel: 10),
        )
        let progress = BattleDefeatProgress(remainingHealth: 25, maximumHealth: 100)
        let normal = ExperienceScaling.battleAward(playerLevel: 10, enemyLevel: 10)
        controller.recordOutcome(step: step, won: false, defeatProgress: progress)
        #expect(controller.state.heroXP == progress.experienceAward(from: normal))
        #expect(controller.state.companionXP == progress.experienceAward(from: normal))
        #expect(controller.state.battlesWon == 0)
        #expect(controller.selectNextStep() == step)
        #expect(!controller.isComplete)
    }

    @Test func `Easy Contracts earn recovery XP without clearing or prolonging advancing content`() throws {
        let step = BalanceTestFixtures.step(enemyLevel: 20)
        let controller = InterleavingPlayerController(
            campaignTracker: .init(steps: [step]), spireTracker: .init(steps: []), labyrinthTracker: .init(steps: []),
            initialState: PlayerProgressionState(heroLevel: 10, companionLevel: 10), worldSeed: 43,
        )
        controller.recordOutcome(step: step, won: false)
        controller.recordOutcome(step: step, won: false)
        let recovery = try #require(controller.selectNextStep())
        try #require(recovery.mode == .contract)
        #expect(recovery.enemyLevel == 7)
        #expect(controller.selectNextStep() == recovery)
        #expect(GameContent.enemy(matching: recovery.enemyID)?.isBoss == false)
        controller.recordOutcome(step: recovery, won: false)
        #expect(controller.selectNextStep() == recovery)
        controller.recordOutcome(step: recovery, won: true)
        #expect(controller.state.heroXP > 0)
        #expect(controller.selectNextStep() == step)
        #expect(!controller.isComplete)
        controller.recordOutcome(step: step, won: true)
        #expect(controller.isComplete)
        #expect(controller.selectNextStep() == nil)
    }
}

extension ModeProgressionToolingTests {
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

        let step = BalanceTestFixtures.step()

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
        let step = BalanceTestFixtures.step()

        let records = (0 ..< (wins + defeats + timeouts)).map { index in
            ProgressionBattleRecord(
                step: step,
                playerLevel: level,
                enemyLevel: level,
                seed: UInt64(index),
                result: BalanceTestFixtures.result(
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

    @Test func `hotspot power rating uses Countess resolved combat stats`() throws {
        let step = BalanceTestFixtures.step(enemyID: "the_blood_countess", enemyLevel: 40, isBoss: true)
        let record = ProgressionBattleRecord(
            step: step, playerLevel: 40, enemyLevel: 40, seed: 11,
            result: BalanceTestFixtures.result(),
        )
        let summary = try #require(HotspotAnalyzer.analyze(records: [record]).first)
        #expect(abs(summary.averageEnemyPowerRating - 5580) < 0.000001)
    }

    @Test func `progression matchup spends legal talents at current level`() {
        let controller = InterleavingPlayerController(
            initialState: PlayerProgressionState(heroLevel: 20, companionLevel: 20),
        )
        let step = BalanceTestFixtures.step(enemyID: "living_armor", enemyLevel: 20)
        let matchup = controller.makeMatchup(for: step, seed: 11)
        let budget = CombatantProgression.at(level: 20).totalTalentPoints
        #expect(matchup.context.heroTalentIDs.count == budget)
        #expect(matchup.context.companionTalentIDs.count == budget)
    }

    @Test func `progression early campaign matchup uses starter gear`() {
        let controller = InterleavingPlayerController(
            initialState: PlayerProgressionState(heroLevel: 2, companionLevel: 2),
        )
        let step = BalanceTestFixtures.step(enemyID: "slime", enemyLevel: 1)
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
        let step = BalanceTestFixtures.step(
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
        #expect(playerAt45.maxHealth == wizard.maxHealth + 88)
        #expect(playerAt45.maxMana == wizard.maxMana + 22)
        let wolf = try #require(GameContent.companion(matching: "wolf"))
        let companionAt45 = CombatantLevelScaler.scale(combatant: wolf, level: 45)
        #expect(companionAt45.maxHealth == wolf.maxHealth + 88)
        #expect(companionAt45.maxMana == 0)

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
        let step = BalanceTestFixtures.step(mode: mode, enemyLevel: 20)
        let matchup = controller.makeMatchup(for: step, seed: 1772)
        let enemy = try #require(GameContent.enemy(matching: step.enemyID))
        #expect(controller.encounterLevel(for: step) == expectedLevel)
        #expect(matchup.enemy.maxHealth == CombatantLevelScaler.scale(enemy: enemy, level: expectedLevel).maxHealth)
    }

    @Test func `mixed party uses truncated average like live play`() {
        let controller = InterleavingPlayerController(
            initialState: PlayerProgressionState(heroLevel: 15, companionLevel: 16),
        )
        let step = BalanceTestFixtures.step(enemyLevel: 20)
        #expect(controller.encounterLevel(for: step) == 18)
    }

    @Test func `overleveled spire win awards no XP`() {
        let step = BalanceTestFixtures.step(
            id: "spire-step",
            mode: .spire,
            containerID: "ironVein",
            containerTitle: "Iron Vein",
            displayTitle: "Iron Vein Floor 1",
            enemyLevel: 2,
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
}

extension ModeProgressionToolingTests {
    @Test(arguments: [
        (false, 800, 1000, HotspotStatus.overtuned),
        (true, 800, 1000, .smooth),
        (false, 950, 1000, .smooth),
        (true, 950, 1000, .undertuned),
        (false, 995, 1000, .undertuned),
        (false, 8, 8, .undertuned),
        (true, 8, 8, .undertuned),
        (false, 0, 8, .overtuned),
        (true, 0, 8, .overtuned),
        (false, 1, 1, .smooth),
    ])
    func `progression uses role bands and flags decided extremes`(
        isBoss: Bool, wins: Int, count: Int, expected: HotspotStatus,
    ) throws {
        let step = BalanceTestFixtures.step(isBoss: isBoss)
        let records = (0 ..< count).map { index in
            ProgressionBattleRecord(
                step: step,
                playerLevel: 10,
                enemyLevel: 10,
                seed: UInt64(index),
                result: BalanceTestFixtures.result(outcome: index < wins ? .victory : .defeat),
            )
        }
        let summary = try #require(HotspotAnalyzer.analyze(records: records).first)
        #expect(summary.status == expected)
        let report = BalanceProgressionReportFormatter.render(
            config: BalanceSweepConfig(mode: .modeProgression),
            hotspots: [summary],
            records: records,
            playerStates: [],
            elapsedSeconds: 0,
        )
        #expect(report.contains("regular enemies `90-98%`, bosses `70-90%` (all tiers)"))
        #expect(!report.contains("<80% or >95%"))
    }
}
