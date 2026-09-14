final class BattleCardPlayRecording {
    private let recording: (BattleTransitionCheckpoint, BattleState, [ActionEvent]) -> Void
    private var pendingEvents: [ActionEvent] = []
    private var cards: [(card: BattleCard, hasAction: Bool)] = []
    private var actions: [BattleResolvedAction] = []

    init(_ recording: @escaping (BattleTransitionCheckpoint, BattleState, [ActionEvent]) -> Void) {
        self.recording = recording
    }

    static func detached(
        _ recording: ((BattleTransitionCheckpoint, BattleState, [ActionEvent]) -> Void)?,
    ) -> ((BattleTransitionCheckpoint, BattleState, [ActionEvent]) -> Void)? {
        recording.map { callback in
            { checkpoint, state, events in
                var snapshot = state
                snapshot.cardPlayRecording = nil
                callback(checkpoint, snapshot, events)
            }
        }
    }

    func append(_ event: ActionEvent) {
        pendingEvents.append(event)
        if !actions.isEmpty {
            actions[actions.count - 1].eventIDs.append(event.id)
        }
    }

    func beginAction(id: Int, actorID: String, abilityID: String, isAttack: Bool, afterEventID: Int) {
        let cardID = cards.last.flatMap { $0.hasAction ? nil : $0.card.id }
        if !cards.isEmpty {
            cards[cards.count - 1].hasAction = true
        }
        actions.append(BattleResolvedAction(
            id: id, actorID: actorID, abilityID: abilityID, cardID: cardID,
            isAttack: isAttack, eventIDs: [], startedAfterEventID: afterEventID,
        ))
    }

    func endAction(state: BattleState) {
        guard let action = actions.popLast() else { return }
        var snapshot = state
        snapshot.cardPlayRecording = nil
        recording(.actionResolved(action), snapshot, [])
    }

    func recordDamage(_ damage: BattleResolvedDamage) {
        guard !actions.isEmpty else { return }
        actions[actions.count - 1].damage.append(damage)
    }

    func record(_ checkpoint: BattleTransitionCheckpoint, state: BattleState) {
        switch checkpoint {
        case let .cardWillPlay(card): cards.append((card, false))
        case .cardActions: _ = cards.popLast()
        default: break
        }
        var snapshot = state
        snapshot.cardPlayRecording = nil
        let events = pendingEvents
        pendingEvents.removeAll(keepingCapacity: true)
        recording(checkpoint, snapshot, events)
    }
}

extension BattleState {
    mutating func recordCardPlay(_ checkpoint: BattleTransitionCheckpoint) {
        cardPlayRecording?.record(checkpoint, state: self)
    }
}
