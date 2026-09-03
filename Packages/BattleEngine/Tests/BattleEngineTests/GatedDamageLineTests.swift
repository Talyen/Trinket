import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct GatedDamageLineTests {
    private func makeContext(frozenEnemy: Bool) -> BattleState {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.iceShot]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100),
            dealOpeningHand: false,
        )
        if frozenEnemy {
            BattleStateTestFactory.seedActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
                for: battle.enemy,
                on: &battle,
            )
        }
        return battle
    }

    @Test func `ice shot shatters a frozen enemy`() {
        var context = makeContext(frozenEnemy: true)
        let events = BattleTurnEngine.performAction(
            ability: .iceShot,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let components = events.filter { $0.kind == .abilityDamage }
        #expect(components.count == 2)
        #expect(components.map(\.keyword) == [.freeze, .physical])
    }

    @Test func `ice shot skips shatter on an unfrozen enemy`() {
        var context = makeContext(frozenEnemy: false)
        let events = BattleTurnEngine.performAction(
            ability: .iceShot,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let components = events.filter { $0.kind == .abilityDamage }
        #expect(components.count == 1)
        #expect(components.map(\.keyword) == [.freeze])
    }
}
