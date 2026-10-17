import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

struct BattleSimulatorTests {
    @Test func `matchup attribution includes only compatible equipped gear`() throws {
        let hero = try #require(GameContent.hero(matching: "knight"))
        let inventory = GameContent.uniqueItems
        let item = try #require(inventory.first { $0.baseType.slot == .weapon })
        var equipment = EquipmentLoadout()
        equipment.equip(item, in: .weapon, inventory: inventory)
        let matchup = try SimulationMatchupBuilder.build(
            hero: hero, companion: #require(GameContent.companions.first),
            enemy: #require(GameContent.enemies.first), tier: .middle,
            heroLoadout: hero.abilityLoadout, companionLoadout: AbilityLoadout(), seed: 42,
            heroGear: .init(inventory: inventory, loadout: equipment),
        )
        #expect(matchup.context.heroItemBaseIDs == [item.baseType.id])
        #expect(matchup.context.heroAffixIDs == item.affixes.map(\.id))
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

    @Test func `sample party loadouts meet damaging floor`() {
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
                #expect(
                    count >= SimulationMatchupBuilder.minimumPartyDamagingAbilities,
                    "\(hero.id)+\(companion.id) damaging count \(count)",
                )
            }
        }

        let supportHeavy = SimulationMatchupBuilder.damagingAbilityCount(
            hero: AbilityLoadout(basic: .block, skill: .smite, ultimate: .moltenBulwark),
            companion: AbilityLoadout(basic: .apple, skill: .heal, ultimate: .panaceaPotion),
        )
        #expect(supportHeavy < SimulationMatchupBuilder.minimumPartyDamagingAbilities)
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
        #expect(withTalent.heroModifiers.triggers.startBattleBlock == 6)
        #expect(withoutTalent.heroModifiers.triggers.startBattleBlock == 0)
        #expect(withTalent.context.heroTalentIDs == ["knight_block_t1_1"])
        #expect(withoutTalent.context.heroTalentIDs.isEmpty)
    }

    @Test func `talent kit comparisons enforce the budget and preserve the requested build`() throws {
        let owner = try #require(GameContent.hero(matching: "knight"))
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first)
        var rng = SeededRandomNumberGenerator(seed: 7)
        let kit = SimulationMatchupBuilder.legalTalentKit(for: owner.id, level: SimulationPowerTier.lateGame.level, using: &rng)
        let focus = BalanceTalentContrastRunner.Focus.kit(.init(owner: owner, kit: kit))
        let context = BalanceContrastContext(
            config: BalanceSweepConfig(), heroes: [owner], companions: [companion], enemies: [enemy],
        )
        let fullCatalog = BalanceTalentContrastRunner.Focus.kit(.init(
            owner: owner, kit: CombatantTalentCatalog.validNodeIDs(for: owner.id),
        ))
        #expect(BalanceTalentContrastRunner.makePair(
            focus: fullCatalog, tier: .early, pairIndex: 0, seed: 7, context: context,
        ) == nil)
        let pair = try #require(BalanceTalentContrastRunner.makePair(
            focus: focus, tier: .lateGame, pairIndex: 0, seed: 7, context: context,
        ))
        #expect(Set(pair.withEntity.context.heroTalentIDs) == kit)
        #expect(pair.withBaseline.context.heroTalentIDs.isEmpty)
        #expect(pair.withEntity.context.companionTalentIDs == pair.withBaseline.context.companionTalentIDs)
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

        #expect(BattleSimulator.makeBattle(matchup: matchup).enemyFaction == .undead)
    }
}
