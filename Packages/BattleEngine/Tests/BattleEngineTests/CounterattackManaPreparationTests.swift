import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CounterattackManaPreparationTests {
    @Test(arguments: [("wizard_mana_t2_1", 0.2, 5), ("warlock_burn_t2_2", 0.5, 6)])
    func `counterattack Mana preparations empower a later attack`(
        talentID: String, expectedPercent: Double, laterDamage: Int,
    ) {
        let ability = Ability(
            id: "mana-counterattack", name: "Mana Counterattack", tier: .basic,
            damageComponents: [DamageComponent(4, keyword: .burn)], criticalChanceBonus: -1,
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 3, heroMana: 3,
            heroModifiers: CombatantTalentCatalog.profile(for: [talentID]), dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let beforePreparation = battle.health(of: battle.enemy)

        _ = BattleTurnEngine.performAction(
            ability: ability, actor: battle.hero, abilityTarget: battle.enemy,
            origin: .counterattack, context: &battle,
        )

        #expect(beforePreparation - battle.health(of: battle.enemy) == 5)
        #expect(battle.mana(of: battle.hero) == 0)
        let pending = battle.roster.runtime(for: battle.hero)?.talents.pending
        #expect((pending?.overchargePercent ?? pending?.nextBurnAttackPercent)?.value == expectedPercent)
        let beforeLaterAttack = battle.health(of: battle.enemy)

        _ = BattleTurnEngine.performAction(
            ability: ability, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )

        #expect(beforeLaterAttack - battle.health(of: battle.enemy) == laterDamage)
        #expect(battle.roster.runtime(for: battle.hero)?.talents.pending.overchargePercent == nil)
        #expect(battle.roster.runtime(for: battle.hero)?.talents.pending.nextBurnAttackPercent == nil)
        let beforeUnpreparedAttack = battle.health(of: battle.enemy)

        _ = BattleTurnEngine.performAction(
            ability: ability, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )

        #expect(beforeUnpreparedAttack - battle.health(of: battle.enemy) == 4)
    }
}
