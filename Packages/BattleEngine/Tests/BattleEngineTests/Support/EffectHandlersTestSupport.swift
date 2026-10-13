import BattleEngine
import TrinketContent
import TrinketCore

enum EffectHandlersTestSupport {
    struct TickObservation {
        let events: [ActionEvent]
        let currentEffect: ActiveEffect?
    }

    static func dispatch(
        _ effect: Effect,
        ability: Ability = Ability(id: "test", name: "Test", tier: .basic),
        source: Combatant? = nil,
        target: Combatant? = nil,
        battle: inout BattleState,
    ) -> EffectApplyOutcome {
        let source = source ?? battle.hero
        let target = target ?? battle.hero
        let handler = EffectHandlers.handler(for: effect.kind)
        let outcome = CombatExecutor.run {
            await handler.apply(effect, ability: ability, source: source, target: target, in: &battle)
        }
        if battle.tracksLog {
            battle.syncLog()
        }
        return outcome
    }

    static func dispatchTick(
        _ active: ActiveEffect,
        target: Combatant,
        battle: inout BattleState,
    ) -> TickObservation {
        let handler = EffectHandlers.handler(for: active.effect.kind)
        battle.roster.mutateRuntime(for: target) {
            $0.activeEffects.removeAll { $0.id == active.id }
            $0.activeEffects.append(active)
        }
        battle.nextEffectID = max(battle.nextEffectID, active.id + 1)
        let outcome = CombatExecutor.run { await handler.advanceTurn(active, on: target, in: &battle) }
        if battle.tracksLog {
            battle.syncLog()
        }
        return TickObservation(
            events: outcome,
            currentEffect: battle.roster.activeEffects(for: target).first { $0.id == active.id },
        )
    }
}
