import BattleEngine
import Foundation
import Observation

enum BattleCardCuePresentationMode: Equatable {
    case preview
    case pressPreview
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
    let startedAt: Date
    let denial: BattlePlayError?
    let resources: [BattleCardAssessment.ResourceUse]

    func windUpEndsAt(releasedAt date: Date) -> Date {
        mode == .pressPreview
            ? startedAt.addingTimeInterval(CombatFeedbackAttackRecipes.timing(isPartyMember: true).preparation)
            : date
    }
}

@MainActor
@Observable
final class BattleCardCueState {
    private(set) var current: BattleCardCue?
    @ObservationIgnored private var nextID = 0
    // Tracks every lifted card for the requiresLift guard; `current` is the
    // single presented cue. A second begin() while one card is lifted keeps
    // both IDs until each commits/cancels, while presentation follows `current`.
    @ObservationIgnored private var liftedCardIDs: Set<Int> = []
    @ObservationIgnored private var clearGeneration = CancellableGeneration()

    func begin(
        cardID: Int,
        assessment: BattleCardAssessment,
        mode: BattleCardCuePresentationMode? = nil,
        at date: Date = .now,
    ) {
        guard assessment.denial == nil else { return }
        liftedCardIDs.insert(cardID)
        let resolvedMode = mode
            ?? (current?.cardID == cardID ? current?.mode : nil)
            ?? .preview
        if let previous = current, previous.cardID == cardID, previous.phase == .lifted {
            current = BattleCardCue(
                id: previous.id, cardID: cardID, actorID: assessment.actorID, phase: .lifted,
                mode: resolvedMode, startedAt: previous.startedAt,
                denial: nil, resources: assessment.resources,
            )
            return
        }
        clearGeneration.invalidate()
        nextID &+= 1
        current = BattleCardCue(
            id: nextID, cardID: cardID, actorID: assessment.actorID, phase: .lifted,
            mode: resolvedMode, startedAt: date,
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
        // Only health denial has a cue presentation (the owner's health-bar
        // pulse). Other errors mean the cue is stale or state is unavailable,
        // so the cue simply cancels.
        guard reason == .insufficientHealth else {
            cancel(cardID: cardID)
            return
        }
        clearGeneration.invalidate()
        nextID &+= 1
        current = BattleCardCue(
            id: nextID, cardID: cardID, actorID: actorID, phase: .denied,
            mode: .preview, startedAt: .now,
            denial: reason, resources: [],
        )
        scheduleClear(after: .milliseconds(400))
    }

    func clear() {
        liftedCardIDs.removeAll()
        clearPresentation()
    }

    private func clearPresentation() {
        clearGeneration.invalidate()
        current = nil
    }

    func hasLift(for cardID: Int) -> Bool {
        liftedCardIDs.contains(cardID)
    }

    private func scheduleClear(after duration: Duration) {
        let generation = clearGeneration.claim()
        clearGeneration.task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self, clearGeneration.isCurrent(generation) else { return }
            current = nil
            clearGeneration.finish(generation: generation)
        }
    }
}
