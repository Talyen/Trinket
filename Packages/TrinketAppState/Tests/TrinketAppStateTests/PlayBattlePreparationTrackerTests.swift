import BattleEngine
import Testing
import TrinketBattleFeature
import TrinketContent
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

    @Test func `unchanged spires inputs reuse launch prepared battle`() throws {
        let context = try AppTestContext()
        let state = try context.makePlaySession()
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let battle = try #require(context.lastBattle)

        state.spires.prepareBattle(for: floor)
        let preparedRevision = battle.preparedBattlePresentationRevision

        state.spires.prepareBattle(for: floor)

        #expect(battle.preparedBattlePresentationRevision == preparedRevision)
    }
}
