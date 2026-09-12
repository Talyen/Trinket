import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

extension BattleCardCombatTests {
    @Test func `enemy block protects against player attack before decaying`() throws {
        let guardAbility = Ability(id: "guard", name: "Guard", tier: .basic, effects: [.shield(.block, 11)])
        let strike = Ability(
            id: "strike", name: "Strike", tier: .basic,
            damageComponents: [DamageComponent(6, keyword: .physical)],
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [strike], enemyAbilities: [guardAbility],
        )
        _ = battle.endTurn()
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 11)
        let card = try #require(battle.hand.cards.first)
        let health = battle.health(of: battle.enemy)
        _ = try battle.playCard(cardID: card.id)
        #expect(battle.health(of: battle.enemy) == health)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 5)
        _ = battle.endTurn()
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 13)
    }

    @Test(arguments: [false, true], [false, true])
    func `enemy block decays before skipped turns and recurring gains`(skipped: Bool, retainsMore: Bool) {
        var effects = [ActiveEffect(id: 1, effect: .shield(.block, 45), remainingTurns: 0)]
        if skipped {
            effects.append(ActiveEffect(id: 2, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0))
        }
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(),
            activeEnemyEffects: effects,
            enemyModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(block: BlockTriggers(
                blockPerTurn: 7, blockRetainsThreeQuarters: retainsMore,
            ))),
        )
        let events = battle.endTurn()
        #expect(events.contains { $0.effectKind == .controlActionSkipped } == skipped)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == (retainsMore ? 37 : 29))
    }

    @Test func `party block absorbs enemy attack before round end decay`() {
        let strike = Ability(
            id: "strike", name: "Strike", tier: .basic,
            damageComponents: [DamageComponent(6, keyword: .physical, target: .hero)],
        )
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100, abilities: [strike]),
            activeHeroEffects: [ActiveEffect(id: 1, effect: .shield(.block, 11), remainingTurns: 0)],
            activeCompanionEffects: [ActiveEffect(id: 2, effect: .shield(.block, 11), remainingTurns: 0)],
        )
        let health = battle.health(of: battle.hero)
        _ = battle.endTurn()
        #expect(battle.health(of: battle.hero) == health)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 2)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 5)
    }
}
