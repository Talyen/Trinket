import Foundation
import TrinketCore
import TrinketContent

/// Orchestrates one global battle tick. `BattleState.advanceOneStep()` is the
/// public facade; this engine owns the tick contract shared with focused unit tests.
public enum BattleLoopEngine {
    public static func advanceOneStep(
        matchup: BattleMatchup,
        context: inout BattleEngineContext
    ) -> BattleStep {
        context.tickCount += 1

        var events = EffectTickEngine.tickAll(context: &context, matchup: matchup)

        if context.roster.isEnemyDefeated || context.roster.isPartyDefeated {
            events.append(contentsOf: context.appendDefeatMilestonesIfNeeded(matchup: matchup))
            return .ended(events: events)
        }

        guard let actor = context.roster.nextReadyRuntime(atTick: context.tickCount)?.combatant else {
            return .effectsOnly(events: events)
        }

        events.append(contentsOf: BattleTurnEngine.act(
            actor: actor,
            matchup: matchup,
            context: &context
        ))
        events.append(contentsOf: context.appendDefeatMilestonesIfNeeded(matchup: matchup))

        if context.roster.isEnemyDefeated || context.roster.isPartyDefeated {
            return .ended(events: events)
        }

        return .acted(actor, events: events)
    }
}
