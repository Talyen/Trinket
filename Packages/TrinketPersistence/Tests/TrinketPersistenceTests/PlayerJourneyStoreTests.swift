import Testing
import TrinketContent
@testable import TrinketPersistence

@Suite @MainActor
final class PlayerJourneyStoreTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func completeStageWriteThroughToSaveStore() throws {
        let journeyStore = PlayerJourneyStore(saveStore: context.makeSaveStore())
        let stage = try #require(GameContent.chapters[0].stages.first)

        journeyStore.complete(stage, in: GameContent.chapters)

        let reloaded = context.makeSaveStore()
        #expect(reloaded.journey.activeStageID == "chapter-1-stage-2")
        #expect(reloaded.journey.completedStageIDs.contains(stage.id))
    }

    @Test func markRewardsClaimedWriteThroughToSaveStore() throws {
        let journeyStore = PlayerJourneyStore(saveStore: context.makeSaveStore())
        let stage = try #require(GameContent.chapters[0].stages.first)
        journeyStore.complete(stage, in: GameContent.chapters)

        journeyStore.markRewardsClaimed(for: stage)

        let reloaded = context.makeSaveStore()
        #expect(reloaded.journey.claimedRewardStageIDs.contains(stage.id))
    }
}
