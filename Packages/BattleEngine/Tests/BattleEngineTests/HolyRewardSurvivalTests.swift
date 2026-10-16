import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HolyRewardSurvivalTests {
    @Test(arguments: [false, true])
    func `Nullifying purges only when its Holy attacker survives Thorns`(lethal: Bool) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "nullifying"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        let buff = Effect.criticalChanceBonus(0.1, 2)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemyEffects: [
                ActiveEffect(id: 1, effect: .thorns(1), remainingTurns: 0),
                ActiveEffect(id: 2, effect: buff, remainingTurns: 2),
            ],
            heroHealth: lethal ? 1 : 2, heroModifiers: profile, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true

        let attack = battle.resolveTestDamage(
            1, keyword: .holy,
            options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )

        #expect(attack.healthLost == 1)
        #expect(battle.health(of: battle.hero) == (lethal ? 0 : 1))
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect == buff } == lethal)
        #expect(attack.events.contains { $0.effectKind == .purgeApplied } == !lethal)
    }
}
