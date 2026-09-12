final class BattleCardPlayRecording {
    private let recording: (BattleTransitionCheckpoint, BattleState, [ActionEvent]) -> Void
    private var pendingEvents: [ActionEvent] = []

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
    }

    func record(_ checkpoint: BattleTransitionCheckpoint, state: BattleState) {
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
