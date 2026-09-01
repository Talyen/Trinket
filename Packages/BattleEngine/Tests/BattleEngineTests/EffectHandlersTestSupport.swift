import BattleEngine
import TrinketContent
import TrinketCore
import TrinketTestSupport

enum EffectHandlersTestSupport {
    static func makeBattle(
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        enemy: Combatant? = nil,
        initialGold: Int = 0,
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: hero ?? CombatantFixtures.passiveHero(),
            companion: companion ?? CombatantFixtures.passiveCompanion(),
            enemy: enemy ?? CombatantFixtures.passiveEnemy(),
            initialGold: initialGold,
        )
    }

    static func dispatch(
        _ effect: Effect,
        ability: Ability = Ability(id: "test", name: "Test", tier: .basic),
        source: Combatant,
        target: Combatant,
        battle: inout BattleState,
    ) -> EffectApplyOutcome {
        guard let handler = EffectHandlers.handler(for: effect.kind) else {
            preconditionFailure("Missing handler for \(effect.kind)")
        }
        return battle.withEngineContext { context in
            handler.apply(
                effect,
                ability: ability,
                source: source,
                target: target,
                in: &context,
            )
        }
    }

    static func dispatchTick(
        _ active: ActiveEffect,
        target: Combatant,
        battle: inout BattleState,
    ) -> EffectTurnOutcome {
        guard let handler = EffectHandlers.handler(for: active.effect.kind) else {
            preconditionFailure("Missing handler for \(active.effect.kind)")
        }
        return battle.withEngineContext { context in
            handler.advanceTurn(active, on: target, in: &context)
        }
    }
}
