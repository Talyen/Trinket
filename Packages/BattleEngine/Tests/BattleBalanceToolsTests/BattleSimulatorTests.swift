import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

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

        let first = BattleSimulator.run(matchup: matchup, policy: .greedy)
        let second = BattleSimulator.run(matchup: matchup, policy: .greedy)

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

    @Test func samplePartyLoadoutsMeetDamagingFloor() throws {
        for hero in GameContent.heroes {
            for companion in GameContent.companions {
                var rng = SeededRandomNumberGenerator(seed: 11)
                let pair = SimulationMatchupBuilder.samplePartyLoadouts(
                    hero: hero,
                    companion: companion,
                    using: &rng
                )
                let count = SimulationMatchupBuilder.damagingAbilityCount(
                    hero: pair.hero,
                    companion: pair.companion
                )
                try #expect(
                    count >= SimulationMatchupBuilder.minimumPartyDamagingAbilities,
                    "\(hero.id)+\(companion.id) damaging count \(count)"
                )
            }
        }

        let supportHeavy = SimulationMatchupBuilder.damagingAbilityCount(
            hero: AbilityLoadout(basic: .block, skill: .smite, ultimate: .moltenBulwark),
            companion: AbilityLoadout(basic: .apple, skill: .heal, ultimate: .panaceaPotion)
        )
        try #expect(supportHeavy < SimulationMatchupBuilder.minimumPartyDamagingAbilities)
    }

    @Test func matchupBuilderAppliesUnlockedTalentsToCombatBuild() throws {
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
            heroTalents: ["knight_block_t1_1"]
        )
        let withoutTalent = SimulationMatchupBuilder.build(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tier: .early,
            heroLoadout: hero.abilityLoadout,
            companionLoadout: companion.abilityLoadout,
            seed: 7
        )
        #expect(withTalent.heroModifiers.triggers.blockPerTurn == 2)
        #expect(withoutTalent.heroModifiers.triggers.blockPerTurn == 0)
        #expect(withTalent.context.heroTalentIDs == ["knight_block_t1_1"])
        #expect(withoutTalent.context.heroTalentIDs.isEmpty)
    }

    @Test func talentKitContrastIsLegalOnlyWhenPointsCoverCatalog() throws {
        let owner = try #require(GameContent.heroes.first { $0.id == "knight" })
        let focus = BalanceTalentContrastRunner.KitFocus(
            owner: owner,
            kit: CombatantTalentCatalog.validNodeIDs(for: owner.id)
        )
        #expect(!BalanceTalentContrastRunner.isKitLegal(focus: focus, tier: .early))
        #expect(!BalanceTalentContrastRunner.isKitLegal(focus: focus, tier: .middle))
        #expect(BalanceTalentContrastRunner.isKitLegal(focus: focus, tier: .lateGame))
    }
}
