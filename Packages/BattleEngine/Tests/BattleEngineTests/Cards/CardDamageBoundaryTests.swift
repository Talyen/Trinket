import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CardDamageBoundaryTests {
    @Test(arguments: [Int.max, Int.max / 2])
    func `large Kindled preparation resolves a doubled Burn card and its costs and rewards`(bonus: Int) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.appliesFightPacing = false
        let hero = battle.hero
        _ = EffectHandlersTestSupport.dispatch(
            .nextBurnBonus(1), source: hero, target: hero, battle: &battle,
        )
        _ = EffectHandlersTestSupport.dispatch(
            .nextBurnBonus(bonus), source: hero, target: hero, battle: &battle,
        )
        battle.appendEffect(.nextStrikeDouble, to: hero, sourceID: hero.id, remainingTurns: 0)
        DefensePoolEngine.set(4, on: hero, in: &battle)
        let ability = Ability(
            id: "prepared-burn-boundary", name: "Prepared Burn", tier: .basic,
            damageComponents: [DamageComponent(1, target: .actor), DamageComponent(2, keyword: .burn)],
            targetedEffects: [TargetedEffect(.resourceGain(.gold, 2))],
            criticalChanceBonus: -1, blockCost: 2,
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)

        let events = try battle.playCard(cardID: card.id).events

        #expect(battle.isEnemyDefeated)
        #expect(battle.health(of: hero) == 19)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: hero)) == 2)
        #expect(battle.gold == 2)
        #expect(events.filter { $0.kind == .abilityDamage && $0.targetID == hero.id }.map(\.amount) == [1])
        #expect(!battle.activeEffects(of: hero).contains {
            $0.effect.kind == .nextBurnBonus || $0.effect.kind == .nextStrikeDouble
        })
    }
}
