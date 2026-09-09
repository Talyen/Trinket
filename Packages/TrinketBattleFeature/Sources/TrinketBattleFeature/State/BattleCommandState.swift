import BattleEngine
import Foundation

struct BattleCommandState {
    enum Phase {
        case inactive, opening, turn, ready, outcome
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

struct BattleTransitionFrame {
    let checkpoint: BattleTransitionCheckpoint
    let snapshot: BattlePresentationSnapshot
    let events: [ActionEvent]
}

struct BattleTransitionPlayback {
    enum Kind {
        case opening, turn
    }

    let configurationID: UUID
    let frames: [BattleTransitionFrame]
    private(set) var nextIndex = 0
    private(set) var currentSnapshot: BattlePresentationSnapshot?

    mutating func next() -> BattleTransitionFrame? {
        guard nextIndex < frames.count else { return nil }
        let frame = frames[nextIndex]
        nextIndex += 1
        currentSnapshot = frame.snapshot
        return frame
    }
}
