@MainActor
struct PlayBattlePreparationTracker<Input: Equatable> {
    private var cached: Input?

    mutating func notePrepared(_ input: Input) {
        cached = input
    }

    mutating func invalidate() {
        cached = nil
    }

    func shouldPrepare(for newInput: Input, hasPreparedRun: Bool) -> Bool {
        newInput != cached || !hasPreparedRun
    }
}
