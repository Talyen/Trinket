import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct FeintStrikeRegressionTests {
    @Test(arguments: [false, true])
    func `Feint Strike refreshes its own preparation while retaining Shared Current`(hasSharedCurrent: Bool) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: CombatantTalentCatalog.profile(for: hasSharedCurrent ? ["druid_mana_t3_1"] : []),
            companionModifiers: CombatantTalentCatalog.profile(for: ["fox_dodge_t1_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        if hasSharedCurrent {
            _ = CombatTriggerEngine.afterHeroTalentSpendMana(actor: battle.hero, amount: 1, empowered: true, in: &battle)
        }

        for _ in 0 ..< 2 {
            _ = CombatTriggerEngine.afterDodge(by: battle.companion, attackerID: battle.enemy.id, in: &battle)
        }
        battle.turnCount += 1
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        _ = CombatTriggerEngine.afterDodge(by: battle.companion, attackerID: battle.enemy.id, in: &battle)

        let request = DamageRequest(
            amount: 3, target: battle.enemy, keyword: .physical, sourceActorID: battle.companion.id,
            options: DamageOperation.attack(
                tier: .basic, scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
            ),
        )
        let preparedDamage = hasSharedCurrent ? 5 : 3
        #expect(battle.effectSummaries(of: battle.companion).contains {
            $0.text == "Prepared Damage: Your next attack deals \(preparedDamage) additional damage."
        })
        #expect(battle.resolveDamage(request).healthLost == 3 + preparedDamage)
        #expect(battle.resolveDamage(request).healthLost == 3)

        // Spending the preparation does not reopen the same turn's first-Dodge allowance.
        _ = CombatTriggerEngine.afterDodge(by: battle.companion, attackerID: battle.enemy.id, in: &battle)
        #expect(battle.resolveDamage(request).healthLost == 3)

        battle.turnCount += 1
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        _ = CombatTriggerEngine.afterDodge(by: battle.companion, attackerID: battle.enemy.id, in: &battle)
        #expect(battle.resolveDamage(request).healthLost == 6)
    }
}
