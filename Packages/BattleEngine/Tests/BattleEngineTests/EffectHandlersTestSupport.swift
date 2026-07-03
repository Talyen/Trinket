import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

enum EffectHandlersTestSupport {
    static func makeBattle(
        hero: Combatant? = nil,
        pet: Combatant? = nil,
        enemy: Combatant? = nil,
        initialGold: Int = 0
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: hero ?? CombatantFixtures.combatant(id: "hero", role: .hero),
            pet: pet ?? CombatantFixtures.combatant(id: "pet", role: .pet),
            enemy: enemy ?? CombatantFixtures.combatant(id: "enemy", role: .enemy),
            initialGold: initialGold
        )
    }

    static func dispatch(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action: ActionApplyContext = ActionApplyContext(),
        battle: inout BattleState
    ) -> EffectApplyOutcome {
        battle.withEngineContext { context in
            EffectHandlers.all[effect.kind]!.apply(
                effect,
                ability: ability,
                source: source,
                target: target,
                action: action,
                in: &context
            )
        }
    }

    static func dispatchTick(
        _ active: ActiveEffect,
        target: Combatant,
        battle: inout BattleState
    ) -> EffectTickOutcome {
        battle.withEngineContext { context in
            EffectHandlers.all[active.effect.kind]!.tick(active, on: target, in: &context)
        }
    }
}
