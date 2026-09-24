import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct BloodOmenDeathsDoorTests {
    @Test(arguments: [1, 2])
    func `Blood Omen draws after a Health loss protected by Deaths Door`(initialHealth: Int) {
        var modifiers = CombatModifierProfile.zero
        modifiers.triggers.drawOnHealthLoss = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash], heroModifiers: modifiers,
            dealOpeningHand: false,
        )
        let hero = battle.hero
        let enemy = battle.enemy
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = initialHealth }
        battle.appliesFightPacing = false

        _ = battle.resolveDamage(DamageRequest(
            amount: 1, target: hero, keyword: .physical, sourceActorID: enemy.id,
            options: .attack(accuracy: .unavoidable),
        ))

        #expect(battle.roster.hero.currentHealth == 1)
        #expect(battle.hand.cards.count == 1)
        #expect(battle.turnCadence.healthLossDrawOwners.contains(.hero))
    }
}
