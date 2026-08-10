import BattleBalanceTools
import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleSimulatorTests {
    @Test func greedyPolicyReachesOutcomeDeterministically() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first)

        let matchup = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: .early,
            heroLoadout: hero.abilityLoadout,
            companionLoadout: companion.abilityLoadout,
            seed: 42
        )

        let first = BattleSimulator.run(matchup: matchup, policy: GreedyHeuristicPolicy())
        let second = BattleSimulator.run(matchup: matchup, policy: GreedyHeuristicPolicy())

        #expect(first == second)
        #expect(first.timedOut == false || first.actions > 0)
    }

    @Test func tracksEventsFalseKeepsEventLogEmpty() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first { !$0.isBoss })
        var battle = BattleState(
            hero: hero,
            companion: companion,
            enemy: enemy.combatant,
            rngSeed: 7,
            tracksLog: false,
            tracksEvents: false
        )
        #expect(battle.events.isEmpty)

        if let card = battle.hand.cards.first(where: { battle.isCardPlayable($0) }) {
            _ = try battle.playCard(cardID: card.id, rebuildLog: false)
        } else {
            _ = battle.endTurn(rebuildLog: false)
        }

        #expect(battle.events.isEmpty)
    }

    @Test func midTierGearUsesBuildAlignedAffixesOnly() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first)
        let matchup = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: .middle,
            heroLoadout: hero.abilityLoadout,
            companionLoadout: companion.abilityLoadout,
            seed: 99
        )

        let buildKeywords = Set(matchup.context.heroLoadout.abilities.flatMap(\.keywords))
        let definitions = Dictionary(
            uniqueKeysWithValues: GameContent.itemAffixDefinitions.map { ($0.id, $0) }
        )
        for affixID in matchup.context.heroAffixIDs {
            let definition = try #require(definitions[affixID])
            #expect(definition.isAligned(withBuildKeywords: buildKeywords))
        }
        #expect(!(matchup.context.heroAffixIDs.isEmpty))
    }

    @Test func sampleLoadoutIncludesAllTiersByDefault() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        var rng = SeededRandomNumberGenerator(seed: 5)
        let loadout = SimulationMatchupBuilder.sampleLoadout(for: hero, using: &rng)
        #expect(loadout.ultimate != nil)
        #expect(loadout.basic != nil)
        #expect(loadout.skill != nil)
    }

    @Test func identitySweepProducesMarkdownWithSecondaryMetrics() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 4,
                seed: 3,
                tiers: [.early],
                jobs: 1
            )
        )
        #expect(report.records.count == 4)
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("# Balance Sweep Report"))
        #expect(markdown.contains("### Heroes"))
        #expect(markdown.contains("### Duration"))
        #expect(markdown.contains("### Party Abilities"))
        #expect(markdown.contains("### Enemy Abilities"))
        #expect(markdown.contains("### Enemy Traits"))
        #expect(markdown.contains("SHORT%"))
        #expect(markdown.contains("Avg rounds"))
        #expect(report.records.allSatisfy { !$0.enemyAbilityIDs.isEmpty })
        #expect(report.records.allSatisfy { !$0.enemyTraitID.isEmpty })
    }

    @Test func parallelIdentityMatchesSequentialOutcomes() {
        let sequential = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 6,
                seed: 11,
                tiers: [.early],
                jobs: 1
            )
        )
        let parallel = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 6,
                seed: 11,
                tiers: [.early],
                jobs: 4
            )
        )
        #expect(sequential.records.map(\.result) == parallel.records.map(\.result))
        #expect(sequential.records.map(\.seed) == parallel.records.map(\.seed))
    }

    @Test func abilityContrastProducesLiftRows() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .abilityContrast,
                battlesPerTier: 8,
                seed: 21,
                tiers: [.early],
                jobs: 1
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
                battlesPerTier: 6,
                seed: 22,
                tiers: [.middle],
                jobs: 1
            )
        )
        #expect(!(report.affixContrasts.isEmpty))
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

        let overtunedRecord = ProgressionBattleRecord(
            step: step,
            playerLevel: 5,
            enemyLevel: 5,
            seed: 1,
            result: BattleSimResult(
                outcome: .defeat,
                rounds: 10,
                actions: 20,
                timedOut: false,
                partyHPRemainingFraction: 0,
                enemyHPRemainingFraction: 0.8
            )
        )

        let summaries = HotspotAnalyzer.analyze(records: [overtunedRecord])
        let summary = try #require(summaries.first)
        #expect(summary.status == .overtuned)
        #expect(summary.isFlagged == true)
    }

    @Test func modeProgressionSweepProducesReport() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .modeProgression,
                battlesPerTier: 2,
                seed: 42,
                jobs: 1
            )
        )
        #expect(report.config.mode == .modeProgression)
        #expect(report.progressionPlayerStates.count == 2)
        #expect(!(report.progressionRecords.isEmpty))
        #expect(!(report.progressionHotspots.isEmpty))
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("# Multi-Mode Progression & Hotspot Balance Report"))
        #expect(markdown.contains("Progression Summary"))
        #expect(markdown.contains("**Simulated Runs**: 2"))
        #expect(markdown.contains("**Total Battles Simulated**: \(report.progressionRecords.count)"))
    }
}
