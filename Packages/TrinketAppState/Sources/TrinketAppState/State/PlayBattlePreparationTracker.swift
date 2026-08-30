import BattleEngine

@MainActor
struct PlayBattlePreparationTracker<Input: Equatable> {
    private var cached: Input?

    var hasCached: Bool {
        cached != nil
    }

    mutating func notePrepared(_ input: Input) {
        cached = input
    }

    mutating func invalidate() {
        cached = nil
    }

    func shouldPrepare(for newInput: Input, lifecycle: BattleLifecyclePhase, hasPreparedRun: Bool) -> Bool {
        newInput != cached || lifecycle == .idle || !hasPreparedRun
    }
}
