import Foundation
import TrinketContent
import TrinketCore

/// One step of the battle loop. `events` holds only the delta emitted during
/// this step (effect ticks, the acting combatant's turn, defeat milestones).
/// The cumulative stream lives on `BattleState.events`.
public enum BattleStep: Equatable {
    case effectsOnly(events: [ActionEvent])
    case acted(Combatant, events: [ActionEvent])
    case ended(events: [ActionEvent])

    public var events: [ActionEvent] {
        switch self {
        case let .effectsOnly(events), let .acted(_, events), let .ended(events):
            return events
        }
    }
}
