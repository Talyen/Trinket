import BattleEngine
import Observation
import TrinketCore

enum BattleCardCueKind: Int, Equatable {
    case cleanse, restore, protect, attack, prepare, gain
    case deniedHealth, deniedControl, deniedDefeated
}

struct BattleRecipientCue: Equatable {
    let kind: BattleCardCueKind
    let keyword: Keyword?
}

struct BattleCardCue: Equatable {
    enum Phase: Equatable {
        case lifted, committed, denied
    }

    let id: Int
    let cardID: Int
    let actorID: String
    var phase: Phase
    let recipients: [String: BattleRecipientCue]
    let resources: [BattleCardAssessment.ResourceUse]
}

@MainActor
@Observable
final class BattleCardCueState {
    private(set) var current: BattleCardCue?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var liftedCardIDs: Set<Int> = []
    @ObservationIgnored private var clearTask: Task<Void, Never>?

    func begin(cardID: Int, assessment: BattleCardAssessment) {
        guard assessment.denial == nil else { return }
        liftedCardIDs.insert(cardID)
        if let previous = current, previous.cardID == cardID, previous.phase == .lifted {
            current = BattleCardCue(
                id: previous.id, cardID: cardID, actorID: assessment.actorID, phase: .lifted,
                recipients: BattleCardCueRecipes.recipients(for: assessment), resources: assessment.resources,
            )
            return
        }
        clearTask?.cancel()
        generation &+= 1
        current = BattleCardCue(
            id: generation, cardID: cardID, actorID: assessment.actorID, phase: .lifted,
            recipients: BattleCardCueRecipes.recipients(for: assessment), resources: assessment.resources,
        )
    }

    func commit(cardID: Int) {
        liftedCardIDs.remove(cardID)
        guard current?.cardID == cardID, current?.phase == .lifted else { return }
        current?.phase = .committed
        scheduleClear(after: .milliseconds(220))
    }

    func cancel(cardID: Int) {
        liftedCardIDs.remove(cardID)
        guard current?.cardID == cardID, current?.phase == .lifted else { return }
        clearPresentation()
    }

    func deny(cardID: Int, actorID: String, reason: BattlePlayError, controlKeyword: Keyword?) {
        liftedCardIDs.remove(cardID)
        let recipient: BattleRecipientCue
        switch reason {
        case .insufficientHealth: recipient = .init(kind: .deniedHealth, keyword: .health)
        case .ownerSkipping: recipient = .init(kind: .deniedControl, keyword: controlKeyword)
        case .ownerDefeated: recipient = .init(kind: .deniedDefeated, keyword: nil)
        case .battleOver, .notPlayerTurn, .cardNotInHand:
            cancel(cardID: cardID)
            return
        }
        clearTask?.cancel()
        generation &+= 1
        current = BattleCardCue(
            id: generation, cardID: cardID, actorID: actorID, phase: .denied,
            recipients: [actorID: recipient], resources: [],
        )
        scheduleClear(after: .milliseconds(400))
    }

    func clear() {
        liftedCardIDs.removeAll()
        clearPresentation()
    }

    private func clearPresentation() {
        clearTask?.cancel()
        clearTask = nil
        generation &+= 1
        current = nil
    }

    func hasLift(for cardID: Int) -> Bool {
        liftedCardIDs.contains(cardID)
    }

    private func scheduleClear(after duration: Duration) {
        clearTask?.cancel()
        let token = generation
        clearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self, generation == token else { return }
            current = nil
            clearTask = nil
        }
    }
}
