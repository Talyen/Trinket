import Testing
@testable import TrinketAppState

@MainActor
struct PlayBattlePreparationTrackerTests {
    @Test func `shouldPrepare behaves correctly with cache and prepared run`() {
        var tracker = PlayBattlePreparationTracker<String>()
        #expect(tracker.shouldPrepare(for: "stage-1", hasPreparedRun: false))
        #expect(tracker.shouldPrepare(for: "stage-1", hasPreparedRun: true))

        tracker.notePrepared("stage-1")
        #expect(!tracker.shouldPrepare(for: "stage-1", hasPreparedRun: true))
        #expect(tracker.shouldPrepare(for: "stage-1", hasPreparedRun: false))
        #expect(tracker.shouldPrepare(for: "stage-2", hasPreparedRun: true))

        tracker.invalidate()
        #expect(tracker.shouldPrepare(for: "stage-1", hasPreparedRun: true))
    }
}
