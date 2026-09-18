import BattleEngine
import Foundation

struct BattleCommandState {
    enum Phase {
        case inactive, opening, ready, outcome
    }

    private(set) var phase: Phase = .inactive
    private(set) var isSuspended = false

    var acceptsCommands: Bool {
        phase == .ready && !isSuspended
    }

    mutating func transition(to phase: Phase) {
        self.phase = phase
    }

    mutating func suspend(_ suspended: Bool) {
        isSuspended = suspended
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
    var actions: [BattleResolvedAction] = []
}
