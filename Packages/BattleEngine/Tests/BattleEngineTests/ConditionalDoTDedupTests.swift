import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct ConditionalDoTDedupTests {
    @Test func damageComponentAppliesDoTStackWithoutImmediateTick() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.kindling]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        var context = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            rngSeed: BattleTestFixtures.deterministicNonCriticalSeed,
            dealOpeningHand: false
        )
        let startingHealth = context.roster.health(for: enemy)

        let events = BattleTurnEngine.performAction(
            ability: .kindling,
            actor: hero,
            abilityTarget: enemy,
            context: &context
        )

        try #expect(context.roster.activeEffects(for: enemy).contains { $0.effect.keyword == .burn })
        let abilityDamage = events
            .filter { $0.kind == ActionEvent.Kind.abilityDamage }
            .reduce(0) { $0 + $1.amount }
        try #expect(context.roster.health(for: enemy) == startingHealth - abilityDamage)
        try #expect(!events.contains { $0.kind == ActionEvent.Kind.status && $0.keyword == .burn })
    }
}
