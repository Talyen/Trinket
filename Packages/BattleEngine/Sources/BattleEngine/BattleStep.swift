import Foundation
import TrinketCore
import TrinketContent

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
