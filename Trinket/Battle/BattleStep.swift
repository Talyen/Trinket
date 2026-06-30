import Foundation

enum BattleStep: Equatable {
    case effectsOnly(events: [BattleState.ActionEvent])
    case acted(Combatant, events: [BattleState.ActionEvent])
    case ended(events: [BattleState.ActionEvent])

    var events: [BattleState.ActionEvent] {
        switch self {
        case let .effectsOnly(events), let .acted(_, events), let .ended(events):
            return events
        }
    }
}
