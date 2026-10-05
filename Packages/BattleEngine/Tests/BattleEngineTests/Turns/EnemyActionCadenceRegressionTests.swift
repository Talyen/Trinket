import Testing
import TrinketContent
import TrinketContentTestSupport
@testable import BattleEngine

struct EnemyActionCadenceRegressionTests {
    @Test(arguments: ["necromancer", "vampire", "blood_cultist", "the_blood_countess", "banshee"])
    func `enemy Skills cannot pay Health for an unavailable deck benefit`(enemyID: String) throws {
        let enemy = try #require(GameContent.enemy(matching: enemyID))
        let ability = try #require(enemy.combatant.abilityLoadout.skill)
        var heroModifiers = CombatModifierProfile.zero
        heroModifiers.triggers.dodgeChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 1000),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 1000),
            enemy: enemy.combatant,
            heroModifiers: heroModifiers,
        )
        battle.appliesFightPacing = false
        let health = battle.health(of: battle.enemy)
        _ = BattleTurnEngine.performAction(
            ability: ability, actor: battle.enemy, abilityTarget: battle.hero, context: &battle,
        )
        #expect(battle.health(of: battle.enemy) == health)
        #expect(battle.health(of: battle.hero) < 1000)
    }

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

        let dodged = CombatExecutor.run { await BattleCardCombatEngine.resolveEnemyTurn(context: &battle) }
        _ = CombatExecutor.run { await BattleCardCombatEngine.resolveEnemyTurn(context: &battle) }
        let third = CombatExecutor.run { await BattleCardCombatEngine.resolveEnemyTurn(context: &battle) }

        #expect(dodged.contains { $0.effectKind == .dodgeApplied })
        #expect(battle.roster.enemy.actionCount == 3)
        #expect(third.contains { $0.kind == .ability && $0.abilityID == skill.id })
    }
}
