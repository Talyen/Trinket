import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct ConfoundingLootRegressionTests {
    @Test func `Confounding Loot steals Gold and activates Fox theft talents`() {
        let profile = CombatantTalentCatalog.profile(for: [
            "fox_stun_t3_2", "fox_gold_t2_1", "fox_gold_t3_1",
        ])
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.controlMeter(.stun, 20, 20), to: battle.enemy, sourceID: battle.companion.id, remainingTurns: 0)
        for expectedGold in [6, 9] {
            let outcome = battle.resolveDamage(DamageRequest(
                amount: 2, target: battle.enemy, keyword: .stun, sourceActorID: battle.companion.id,
                options: .attack(tier: .basic, guaranteedCritical: true),
            ))
            #expect(outcome.isCritical)
            #expect(battle.gold == expectedGold)
            #expect(battle.roster.companion.talents.pending.nextAttackCriticalBonus?.value == 0.20)
        }
    }
}
