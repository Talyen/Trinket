import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleSimulatorTests {
    @Test func greedyPolicyReachesOutcomeDeterministically() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first)
        let enemy = try #require(GameContent.enemies.first)

        let loadout = hero.abilityLoadout
        let matchup = SimulationMatchupBuilder.build(
            hero: hero,
            pet: pet,
            enemy: enemy,
            tier: .early,
            heroLoadout: loadout,
            petLoadout: pet.abilityLoadout,
            seed: 42
        )

        let first = BattleSimulator.run(matchup: matchup, policy: GreedyHeuristicPolicy())
        let second = BattleSimulator.run(matchup: matchup, policy: GreedyHeuristicPolicy())

        #expect(first == second)
        #expect(first.timedOut == false || first.actions > 0)
    }

    @Test func tracksEventsFalseKeepsEventLogEmpty() throws {
        let hero = try #require(GameContent.heroes.first)
        let pet = try #require(GameContent.pets.first)
        let enemy = try #require(GameContent.enemies.first { !$0.isBoss })
        var battle = BattleState(
            hero: hero,
            pet: pet,
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
        let pet = try #require(GameContent.pets.first)
        let enemy = try #require(GameContent.enemies.first)
        let matchup = SimulationMatchupBuilder.build(
            hero: hero,
            pet: pet,
            enemy: enemy,
            tier: .middle,
            heroLoadout: hero.abilityLoadout,
            petLoadout: pet.abilityLoadout,
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

    @Test func tinySweepProducesMarkdown() {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                battlesPerTier: 2,
                seed: 3,
                tiers: [.early]
            )
        )
        #expect(report.records.count == 2)
        let markdown = BalanceMarkdownReporter.render(report)
        #expect(markdown.contains("# Balance Sweep Report"))
        #expect(markdown.contains("### Heroes"))
    }

    @Test func wilsonIntervalContainsPointEstimate() {
        let ci = BalanceStatsAggregator.wilson(wins: 80, battles: 100)
        #expect(ci.low <= 0.80)
        #expect(ci.high >= 0.80)
        #expect(ci.low < ci.high)
    }
}
