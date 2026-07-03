import Foundation
import TrinketCore
import TrinketContent

/// Orchestrates one global battle tick: effect ticks, ready-actor selection,
/// turn execution, and defeat milestones.
///
/// **Tick contract**
/// 1. `context.tickCount` is incremented at the start of each step.
/// 2. Effect ticks run for living combatants in order: enemy, then hero, then pet.
/// 3. If the battle ended during effect ticks, emit defeat milestones and return `.ended`.
/// 4. Otherwise pick the next ready actor (at most one acts per step) using roster
///    scheduling rules.
/// 5. Execute that actor's turn (or consume prevention), append defeat milestones
///    if needed, and return `.acted`, `.effectsOnly`, or `.ended`.
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

        guard let actor = BattleTurnEngine.readyCombatants(in: context).first else {
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
