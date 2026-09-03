import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct DetonateDoTTests {
    private func makeContext() -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.combustion]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100),
            dealOpeningHand: false,
        )
    }

    @Test func `combustion consumes burn for bonus damage`() {
        var context = makeContext()
        let before = context.roster.health(for: context.enemy)
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(6), remainingTurns: 0)],
            for: context.enemy,
            on: &context,
        )
        _ = BattleTurnEngine.performAction(
            ability: .combustion,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let remainingBurn = context.roster.activeEffects(for: context.enemy).filter { $0.effect.keyword == .burn }
        #expect(remainingBurn.isEmpty)
        let lost = before - context.roster.health(for: context.enemy)
        #expect(lost > 4)
    }

    @Test func `combustion detonates even freshly applied burn`() {
        var context = makeContext()
        let before = context.roster.health(for: context.enemy)
        _ = BattleTurnEngine.performAction(
            ability: .combustion,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let remainingBurn = context.roster.activeEffects(for: context.enemy).filter { $0.effect.keyword == .burn }
        #expect(remainingBurn.isEmpty)
        let lost = before - context.roster.health(for: context.enemy)
        #expect(lost > 4)
    }
}
