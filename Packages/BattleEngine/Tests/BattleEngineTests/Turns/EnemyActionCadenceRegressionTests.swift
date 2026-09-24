import Testing
import TrinketContent
@testable import BattleEngine

struct EnemyActionCadenceRegressionTests {
    private let basic = Ability(id: "cadence-basic", name: "Basic", tier: .basic, directDamage: 1)
    private let skill = Ability(id: "cadence-skill", name: "Skill", tier: .skill, directDamage: 1)

    @Test func `dodged enemy attack advances the ability cadence`() {
        var companionModifiers = CombatModifierProfile.zero
        companionModifiers.triggers.negateFirstEnemyAttack = true
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [basic, skill], heroMaxHealth: 100, companionMaxHealth: 100,
            companionModifiers: companionModifiers, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false

        let dodged = BattleCardCombatEngine.resolveEnemyTurn(context: &battle)
        _ = BattleCardCombatEngine.resolveEnemyTurn(context: &battle)
        let third = BattleCardCombatEngine.resolveEnemyTurn(context: &battle)

        #expect(dodged.contains { $0.effectKind == .dodgeApplied })
        #expect(battle.roster.enemy.actionCount == 3)
        #expect(third.contains { $0.kind == .ability && $0.abilityID == skill.id })
    }
}
