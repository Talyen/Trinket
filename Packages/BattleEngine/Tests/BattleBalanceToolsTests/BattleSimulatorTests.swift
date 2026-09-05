import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

struct BattleSimulatorTests {
    @Test func `greedy policy reaches outcome deterministically`() throws {
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
            seed: 42,
        )

        let first = BattleSimulator.run(matchup: matchup, policy: .greedy)
        let second = BattleSimulator.run(matchup: matchup, policy: .greedy)

        #expect(first == second)
        #expect(first.timedOut == false || first.actions > 0)
    }

    @Test func `tracks events false keeps event log empty`() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first { !$0.isBoss })
        var battle = BattleState(
            hero: hero,
            companion: companion,
            enemy: enemy.combatant,
            rngSeed: 7,
            tracksLog: false,
            tracksEvents: false,
        )
        #expect(battle.events.isEmpty)

        if let card = battle.hand.cards.first(where: { battle.isCardPlayable($0) }) {
            _ = try battle.playCard(cardID: card.id, rebuildLog: false)
        } else {
            _ = battle.endTurn(rebuildLog: false)
        }

        #expect(battle.events.isEmpty)
    }

    @Test func `mid tier gear uses build aligned affixes only`() throws {
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
            seed: 99,
        )

        let buildKeywords = Set(matchup.context.heroLoadout.abilities.flatMap(\.keywords))
        let definitions = Dictionary(
            uniqueKeysWithValues: GameContent.itemAffixDefinitions.map { ($0.id, $0) },
        )
        for affixID in matchup.context.heroAffixIDs {
            let definition = try #require(definitions[affixID])
            #expect(definition.isAligned(withBuildKeywords: buildKeywords))
        }
        #expect(!(matchup.context.heroAffixIDs.isEmpty))
    }

    @Test func `sample loadout includes all tiers by default`() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        var rng = SeededRandomNumberGenerator(seed: 5)
        let loadout = SimulationMatchupBuilder.sampleLoadout(for: hero, using: &rng)
        #expect(loadout.ultimate != nil)
        #expect(loadout.basic != nil)
        #expect(loadout.skill != nil)
    }

    @Test func `sample party loadouts meet damaging floor`() throws {
        for hero in GameContent.heroes {
            for companion in GameContent.companions {
                var rng = SeededRandomNumberGenerator(seed: 11)
                let pair = SimulationMatchupBuilder.samplePartyLoadouts(
                    hero: hero,
                    companion: companion,
                    using: &rng,
                )
                let count = SimulationMatchupBuilder.damagingAbilityCount(
                    hero: pair.hero,
                    companion: pair.companion,
                )
                try #expect(
                    count >= SimulationMatchupBuilder.minimumPartyDamagingAbilities,
                    "\(hero.id)+\(companion.id) damaging count \(count)",
                )
            }
        }

        let supportHeavy = SimulationMatchupBuilder.damagingAbilityCount(
            hero: AbilityLoadout(basic: .block, skill: .smite, ultimate: .moltenBulwark),
            companion: AbilityLoadout(basic: .apple, skill: .heal, ultimate: .panaceaPotion),
        )
        try #expect(supportHeavy < SimulationMatchupBuilder.minimumPartyDamagingAbilities)
    }

    @Test func `matchup builder applies unlocked talents to combat build`() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first)
        let withTalent = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: .early,
            heroLoadout: hero.abilityLoadout,
            companionLoadout: companion.abilityLoadout,
            seed: 7,
            heroTalents: ["knight_block_t1_1"],
        )
        let withoutTalent = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: .early,
            heroLoadout: hero.abilityLoadout,
            companionLoadout: companion.abilityLoadout,
            seed: 7,
        )
        #expect(withTalent.heroModifiers.triggers.blockPerTurn == 2)
        #expect(withoutTalent.heroModifiers.triggers.blockPerTurn == 0)
        #expect(withTalent.context.heroTalentIDs == ["knight_block_t1_1"])
        #expect(withoutTalent.context.heroTalentIDs.isEmpty)
    }

    @Test func `talent kit contrast is legal only when points cover catalog`() throws {
        let owner = try #require(GameContent.heroes.first { $0.id == "knight" })
        let valid = CombatantTalentCatalog.validNodeIDs(for: owner.id)
        let lateBudget = CombatantProgression.at(level: SimulationPowerTier.lateGame.level).totalTalentPoints
        let kit = Set(valid.prefix(min(valid.count, lateBudget)))
        let focus = BalanceTalentContrastRunner.KitFocus(
            owner: owner,
            kit: kit,
        )
        #expect(!BalanceTalentContrastRunner.isKitLegal(focus: focus, tier: .early))
        #expect(CombatantProgression.at(level: SimulationPowerTier.middle.level).totalTalentPoints >= kit.count
            ? BalanceTalentContrastRunner.isKitLegal(focus: focus, tier: .middle)
            : !BalanceTalentContrastRunner.isKitLegal(focus: focus, tier: .middle))
        #expect(BalanceTalentContrastRunner.isKitLegal(focus: focus, tier: .lateGame))
        let fullFocus = BalanceTalentContrastRunner.KitFocus(owner: owner, kit: valid)
        #expect(!BalanceTalentContrastRunner.isKitLegal(focus: fullFocus, tier: .early))
    }

    @Test func `simulation policies make rejects unknown I ds`() {
        #expect(SimulationPolicies.make(id: PlayPolicy.greedy.rawValue)?.id == PlayPolicy.greedy.rawValue)
        #expect(SimulationPolicies.make(id: PlayPolicy.setupAware.rawValue)?.id == PlayPolicy.setupAware.rawValue)
        #expect(SimulationPolicies.make(id: "setup-v2") == nil)
    }

    @Test func `matchup builder and simulator preserve enemy faction`() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let undeadEnemy = try #require(GameContent.enemies.first { $0.faction == .undead })

        let matchup = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: undeadEnemy,
            tier: .early,
            heroLoadout: hero.abilityLoadout,
            companionLoadout: companion.abilityLoadout,
            seed: 42,
        )

        #expect(matchup.enemyFaction == .undead)

        let result = BattleSimulator.run(matchup: matchup, policy: .greedy, maxRounds: 1)
        #expect(result.actions > 0)
    }
}
