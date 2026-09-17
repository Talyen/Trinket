import BattleEngine
import Observation

enum BattleCardCuePresentationMode: Equatable {
    case preview
    case tapCommit
}

struct BattleCardCue: Equatable {
    enum Phase: Equatable {
        case lifted, committed, denied
    }

    let id: Int
    let cardID: Int
    let actorID: String
    var phase: Phase
    let mode: BattleCardCuePresentationMode
    let denial: BattlePlayError?
    let resources: [BattleCardAssessment.ResourceUse]
}

@MainActor
@Observable
final class BattleCardCueState {
    private(set) var current: BattleCardCue?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var liftedCardIDs: Set<Int> = []
    @ObservationIgnored private var clearTask: Task<Void, Never>?

    func begin(
        cardID: Int,
        assessment: BattleCardAssessment,
        mode: BattleCardCuePresentationMode? = nil,
    ) {
        guard assessment.denial == nil else { return }
        liftedCardIDs.insert(cardID)
        let resolvedMode = mode
            ?? (current?.cardID == cardID ? current?.mode : nil)
            ?? .preview
        if let previous = current, previous.cardID == cardID, previous.phase == .lifted {
            current = BattleCardCue(
                id: previous.id, cardID: cardID, actorID: assessment.actorID, phase: .lifted,
                mode: resolvedMode,
                denial: nil, resources: assessment.resources,
            )
            return
        }
        clearTask?.cancel()
        generation &+= 1
        current = BattleCardCue(
            id: generation, cardID: cardID, actorID: assessment.actorID, phase: .lifted,
            mode: resolvedMode,
            denial: nil, resources: assessment.resources,
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

    func deny(cardID: Int, actorID: String, reason: BattlePlayError) {
        liftedCardIDs.remove(cardID)
        guard reason == .insufficientHealth else {
            cancel(cardID: cardID)
            return
        }
        clearTask?.cancel()
        generation &+= 1
        current = BattleCardCue(
            id: generation, cardID: cardID, actorID: actorID, phase: .denied,
            mode: .preview,
            denial: reason, resources: [],
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
