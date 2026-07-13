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

    @Test func earlyTierOmitsUltimateWhenLocked() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        var rng = SeededRandomNumberGenerator(seed: 5)
        let loadout = SimulationMatchupBuilder.sampleLoadout(for: hero, level: 1, using: &rng)
        #expect(loadout.ultimate == nil)
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
        #expect(markdown.contains("Avg rounds"))
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
                jobs: 2
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
                jobs: 2
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
}
