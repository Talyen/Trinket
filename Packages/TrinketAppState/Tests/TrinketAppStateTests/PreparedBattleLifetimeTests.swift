import Testing
import TrinketContent
@testable import TrinketAppState

extension AppStatePlayFlowTests {
    @Test func `releasing play invalidates a prepared handle retained by presentation`() async throws {
        let runtime = PreparedThenRejectingBattleRuntime()
        var play: PlaySession? = try context.makePlaySession(battleRuntime: runtime)
        let stage = try #require(GameContent.chapters[0].stages.first)
        play?.journey.prepareBattle(for: stage)
        let key = PlayBattleOrigin.journey(stageID: stage.id).runKey
        let handle = try #require(play?.battleCoordinator.preparedRuns[key]?.handle as? FixturePreparedRun)
        #expect(handle.isValid)
        play = nil
        for _ in 0 ..< 10 where handle.isValid {
            await Task.yield()
        }
        #expect(!handle.isValid)
    }
}
