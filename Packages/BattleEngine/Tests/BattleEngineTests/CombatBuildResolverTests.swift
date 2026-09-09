import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct CombatBuildResolverTests {
    @Test(arguments: [0.0, 0.25, 1.0])
    func `shredding ignores only its share of mitigation`(ignored: Double) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(ignoreEnemyMitigationPercent: ignored),
            )),
            enemyModifiers: .init(incomingDamageReductionPercent: 0.8),
        )
        battle.appliesFightPacing = false
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 100, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.hero.id, options: .reaction(),
        ))
        #expect(outcome.healthLost == CombatRounding.scaled(100, multiplier: 1 - 0.8 * (1 - ignored)))
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `beastbond strengthens companion from either wearer`(owner: BattleParticipant) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "beastbond"))
        let item = try ItemFixtures.makeBareItem("ruby_ring", affixes: [affix.resolved(for: .basic)])
        let hero = CombatantFixtures.passiveHero()
        let companion = CombatantFixtures.passiveCompanion()
        let build = CombatBuildResolver.build(
            combatant: owner == .hero ? hero : companion,
            equipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.accessory: item.id]),
            inventory: [item],
        )
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: hero, companion: companion,
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            heroModifiers: owner == .hero ? build.modifiers : .zero,
            companionModifiers: owner == .companion ? build.modifiers : .zero,
        )
        battle.appliesFightPacing = false
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .physical,
            sourceActorID: companion.id,
            options: DamageOperation.effect(scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(outcome.healthLost == 11)
    }

    @Test(arguments: [41, 60, 100, 250, 1000], [false, true])
    func `enemy build keeps growing past forty`(level: Int, isBoss: Bool) throws {
        let enemy = try #require(GameContent.enemies.first { $0.isBoss == isBoss })
        let previous = CombatBuildResolver.build(enemy: enemy, level: level - 1)
        let current = CombatBuildResolver.build(enemy: enemy, level: level)
        let atForty = CombatBuildResolver.build(enemy: enemy, level: 40)
        #expect(current.combatant.maxHealth >= previous.combatant.maxHealth)
        #expect(current.combatant.maxHealth > atForty.combatant.maxHealth)
        #expect(current.modifiers.outgoingDamagePercent > previous.modifiers.outgoingDamagePercent)
        #expect(current.combatant.abilityChoices == enemy.combatant.abilityChoices)
    }
}
