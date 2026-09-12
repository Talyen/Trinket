import BattleEngine
import Foundation

struct BattleCommandState {
    enum Phase {
        case inactive, opening, ready, outcome
    }

    private enum Scene {
        case active(Phase)
        case suspended(Phase)
    }

    private var scene: Scene = .active(.inactive)

    var phase: Phase {
        switch scene {
        case let .active(phase), let .suspended(phase): phase
        }
    }

    var isSuspended: Bool {
        if case .suspended = scene {
            return true
        }
        return false
    }

    var acceptsCommands: Bool {
        if case .active(.ready) = scene {
            return true
        }
        return false
    }

    mutating func transition(to phase: Phase) {
        scene = isSuspended ? .suspended(phase) : .active(phase)
    }

    mutating func suspend(_ suspended: Bool) {
        scene = suspended ? .suspended(phase) : .active(phase)
    }
}

struct BattleTransitionPlayback {
    enum Kind {
        case opening, turn
    }

    let configurationID: UUID
    let snapshot: BattlePresentationSnapshot
    let events: [ActionEvent]
    let automaticCards: [BattleCard]
}
