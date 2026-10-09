import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct BlazingFeathersRegressionTests {
    @Test(arguments: [0, 2, 4])
    func `blazing feathers attaches burn from retaliation health loss without another hit`(block: Int) {
        var profile = CombatantTalentCatalog.profile(for: ["phoenix_burn_t1_1"])
        profile.triggers.onDamageBurnRetaliationChancePercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let enemyHealth = battle.roster.enemy.currentHealth

        let outcome = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.companion, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        let expectedDamage = 4 - block
        let burns = battle.roster.enemy.activeEffects.filter { $0.effect.kind == .burn }
        #expect(enemyHealth - battle.roster.enemy.currentHealth == expectedDamage)
        #expect(burns.reduce(0) { $0 + ($1.effect.potency ?? 0) } == expectedDamage)
        #expect(burns.isEmpty == (expectedDamage == 0))
        #expect(burns.allSatisfy { $0.sourceActorID == battle.companion.id })
        #expect(outcome.events.filter {
            $0.abilityName == "Blazing Feathers" && $0.effectKind == .thornsTriggered
        }.reduce(0) { $0 + $1.amount } == expectedDamage)
    }
}
