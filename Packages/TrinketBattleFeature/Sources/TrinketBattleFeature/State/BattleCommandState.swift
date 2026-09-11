import BattleEngine
import Foundation

struct BattleCommandState {
    enum Phase {
        case inactive, opening, turn, card, ready, outcome
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
    var snapshot: BattlePresentationSnapshot
    var events: [ActionEvent]
    var assessment: BattleCardAssessment?
}

struct BattleTransitionPlayback {
    enum Kind {
        case opening, turn
    }

    let configurationID: UUID
    let frames: [BattleTransitionFrame]
    let initialCardID: Int?
    private(set) var nextIndex = 0
    private(set) var currentSnapshot: BattlePresentationSnapshot?
    private var unrevealedCardIDs: Set<Int> = []

    var hasAutomaticDraws: Bool {
        frames.contains {
            if case .cardsDrawn = $0.checkpoint {
                return true
            }
            return false
        }
    }

    init(configurationID: UUID, frames: [BattleTransitionFrame], initialCardID: Int? = nil) {
        self.configurationID = configurationID
        self.frames = Self.alignCardAnnouncements(frames)
        self.initialCardID = initialCardID
    }

    mutating func next() -> BattleTransitionFrame? {
        guard nextIndex < frames.count else { return nil }
        var frame = frames[nextIndex]
        nextIndex += 1
        switch frame.checkpoint {
        case let .cardsDrawn(cards):
            unrevealedCardIDs.formUnion(cards.map(\.id))
        case let .cardWillPlay(card):
            unrevealedCardIDs.remove(card.id)
        case .ready:
            unrevealedCardIDs.removeAll()
        default:
            break
        }
        frame.snapshot.hand.removeAll { unrevealedCardIDs.contains($0.id) }
        if case let .cardWillPlay(card) = frame.checkpoint,
           !frame.snapshot.hand.contains(where: { $0.id == card.id }) {
            if frame.snapshot.hand.count < BattleHand.maxSize {
                frame.snapshot.hand.append(card)
            } else {
                frame.snapshot.stagedCard = card
            }
        }
        currentSnapshot = frame.snapshot
        return frame
    }

    private static func alignCardAnnouncements(_ recorded: [BattleTransitionFrame]) -> [BattleTransitionFrame] {
        var frames = recorded
        var playIndices: [Int: Int] = [:]
        for index in frames.indices {
            switch frames[index].checkpoint {
            case let .cardPlayed(card):
                playIndices[card.id] = index
            case let .cardActions(card):
                let snapshot = frames[index].snapshot
                let actorID = card.owner == .hero ? snapshot.hero.combatant.id : snapshot.companion.combatant.id
                guard let playIndex = playIndices.removeValue(forKey: card.id),
                      let eventIndex = frames[index].events.firstIndex(where: {
                          $0.kind == .ability && $0.abilityID == card.ability.id && $0.actorID == actorID
                      }) else { continue }
                let announcement = frames[index].events.remove(at: eventIndex)
                frames[playIndex].events.append(announcement)
            default:
                break
            }
        }
        return frames
    }
}
