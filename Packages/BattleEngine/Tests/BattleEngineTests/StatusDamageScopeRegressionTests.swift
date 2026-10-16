import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct StatusDamageScopeRegressionTests {
    @Test(arguments: [40, 50])
    func `Stalk the Wound increases Bleed ticks only below half enemy Health`(enemyHealth: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 100,
            companionModifiers: CombatantTalentCatalog.profile(for: ["panther_bleed_t2_1"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.enemy.currentHealth = enemyHealth
        battle.insertEffect(.bleed(8), to: battle.enemy, sourceID: battle.companion.id, remainingTurns: 2)

        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: battle.enemy, context: &battle) }

        #expect(battle.roster.enemy.currentHealth == enemyHealth - (enemyHealth < 50 ? 10 : 8))
    }

    @Test func `Heavy Impact increases Thorns after Seismic Reversal stuns the attacking enemy`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 100,
            companionModifiers: CombatantTalentCatalog.profile(for: ["bear_physical_t2_2", "bear_stun_t4_1"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        let threshold = ControlMeterEngine.threshold(for: battle.enemy, in: battle)
        battle.insertEffect(
            .controlMeter(.stun, threshold - 1, threshold),
            to: battle.enemy, sourceID: battle.companion.id, remainingTurns: 0,
        )
        DefensePoolEngine.set(1, on: battle.companion, in: &battle)
        battle.insertEffect(.thorns(8), to: battle.companion, sourceID: battle.companion.id, remainingTurns: 0)

        let outcome = battle.recordingResult { context in context.resolveTestDamage(
            2,
            from: .enemy,
            to: .companion,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) }

        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
        #expect(battle.roster.enemy.currentHealth == 89)
        #expect(outcome.events.contains {
            $0.effectKind == .thornsTriggered && $0.abilityName == "Thorns"
                && $0.keyword == .physical && $0.amount == 10
        })
    }
}
