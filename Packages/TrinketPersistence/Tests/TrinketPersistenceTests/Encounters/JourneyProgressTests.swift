import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct JourneyProgressTests {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    @Test func `completing stage unlocks exactly next stage`() throws {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        let secondStage = chapter.stages[1]
        let thirdStage = chapter.stages[2]

        progress.complete(firstStage, in: GameContent.chapters)

        try #expect(progress.isCompleted(firstStage))
        try #expect(progress.isActive(secondStage))
        try #expect(!(progress.isActive(firstStage)))
        try #expect(!(progress.isActive(thirdStage)))
        try #expect(!(progress.isActive(chapter.stages[4])))
    }

    @Test func `chapter completion automatically advances to next chapter`() throws {
        var progress = JourneyProgressState.initial

        for stage in chapter.stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        try #expect(progress.activeStageID == "chapter-2-stage-1")
        try #expect(progress.activeChapterID == "chapter-2")
    }

    @Test func `mark chapter complete without rewards marks only that chapter done`() throws {
        var progress = JourneyProgressState.initial
        progress.markChapterCompleteWithoutRewards("chapter-1")

        let chapter1 = try #require(GameContent.chapters.first { $0.id == "chapter-1" })
        let chapter1StageIDs = Set(chapter1.stages.map(\.id))
        try #expect(progress.completedStageIDs == chapter1StageIDs)
        try #expect(progress.claimedRewardStageIDs == chapter1StageIDs)
        try #expect(progress.activeStageID == "chapter-2-stage-1")
        try #expect(progress.activeChapterID == "chapter-2")
    }

    @Test func `completing final stage ends the campaign`() throws {
        let finalChapter = try #require(GameContent.chapters.last)
        let finalStage = try #require(finalChapter.stages.last)
        var progress = JourneyProgressState.initial

        progress.complete(finalStage, in: GameContent.chapters)

        #expect(progress.isCompleted(finalStage))
        #expect(progress.activeStageID == nil)
        #expect(progress.activeChapterID == finalChapter.id)
    }

    @Test @MainActor func `journey persists progress`() throws {
        let context = try PersistenceTestContext()

        let firstSaveStore = try context.makeSaveStore()
        try firstSaveStore.performBatchMutation { save in
            save.journey.complete(chapter.stages[0], in: GameContent.chapters)
        }

        let secondSaveStore = try context.makeReloadedStore()
        try #expect(secondSaveStore.journey.activeStageID == "chapter-1-stage-2")
        try #expect(secondSaveStore.journey.completedStageIDs.contains("chapter-1-stage-1"))
    }

    @Test @MainActor func `journey persists pinned mystery event I ds`() throws {
        let context = try PersistenceTestContext()

        let event = try #require(GameContent.mysteryEvent(matching: "mana-berries"))
        let firstSaveStore = try context.makeSaveStore()
        try firstSaveStore.performBatchMutation { save in
            save.journey.pinnedMysteryEventIDs["chapter-1-stage-5"] = event.id
        }

        let secondSaveStore = try context.makeReloadedStore()
        try #expect(
            secondSaveStore.journey.pinnedMysteryEventIDs["chapter-1-stage-5"] == event.id,
        )
    }

    @Test @MainActor func `startup repairs duplicate journey stage rows`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let stageID = "chapter-1-stage-5"
        let eventID = try #require(GameContent.mysteryEvent(matching: "mana-berries")?.id)

        do {
            _ = try context.makeSaveStore()
        }
        do {
            let sideContext = try SaveTestSupport.makeSideContext(storeURL: storeURL)
            let journey = try #require(sideContext.fetch(FetchDescriptor<JourneyProgressModel>()).first)
            let completed = JourneyStageProgressModel(
                stageID: stageID,
                isCompleted: true,
                mysteryEventID: eventID,
            )
            let claimed = JourneyStageProgressModel(
                stageID: stageID,
                rewardsClaimed: true,
                mysteryEventID: eventID,
            )
            completed.journey = journey
            claimed.journey = journey
            journey.stages = [completed, claimed]
            sideContext.insert(completed)
            sideContext.insert(claimed)
            try sideContext.save()
        }

        let repairedStore = try context.makeReloadedStore()
        try #expect(repairedStore.journey.completedStageIDs.contains(stageID))
        try #expect(repairedStore.journey.claimedRewardStageIDs.contains(stageID))
        try #expect(repairedStore.journey.pinnedMysteryEventIDs[stageID] == eventID)

        let sideContext = try SaveTestSupport.makeSideContext(storeURL: storeURL)
        let stageRows = try sideContext.fetch(FetchDescriptor<JourneyStageProgressModel>())
        try #expect(stageRows.count(where: { $0.stageID == stageID }) == 1)
    }
}
