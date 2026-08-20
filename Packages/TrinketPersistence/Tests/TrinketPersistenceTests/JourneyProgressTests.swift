import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@MainActor
final class JourneyProgressTests {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    @Test func completingStageUnlocksExactlyNextStage() throws {
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

    @Test func rewardsCanOnlyBeClaimedOncePerStage() throws {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]

        try #expect(!(progress.hasClaimedRewards(for: firstStage)))
        progress.markRewardsClaimed(for: firstStage)
        progress.markRewardsClaimed(for: firstStage)

        try #expect(progress.hasClaimedRewards(for: firstStage))
        try #expect(progress.claimedRewardStageIDs.count == 1)
    }

    @Test func itemRewardCreatesUniqueInstance() throws {
        var inventory = PlayerInventoryState.initial
        let stage = chapter.stages[0]
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))

        inventory.addRewardItem(from: template, for: stage)

        let rewardItem = try #require(inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        try #expect(rewardItem.templateID == "shortsword-basic")
        try #expect(rewardItem.id != rewardItem.templateID)
        try #expect((1 ... 2).contains(rewardItem.affixes.count))
    }

    @Test func chapterCompletionAutomaticallyAdvancesToNextChapter() throws {
        var progress = JourneyProgressState.initial

        for stage in chapter.stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        try #expect(progress.activeStageID == "chapter-2-stage-1")
        try #expect(progress.activeChapterID == "chapter-2")
    }

    @Test func completeChapterMarksOnlyThatChapterDone() throws {
        var progress = JourneyProgressState.initial
        progress.completeChapter("chapter-1")

        let chapter1 = try #require(GameContent.chapters.first { $0.id == "chapter-1" })
        let chapter1StageIDs = Set(chapter1.stages.map(\.id))
        try #expect(progress.completedStageIDs == chapter1StageIDs)
        try #expect(progress.claimedRewardStageIDs == chapter1StageIDs)
        try #expect(progress.activeStageID == "chapter-2-stage-1")
        try #expect(progress.activeChapterID == "chapter-2")
    }

    @Test func completeAllStagesMarksEntireCampaignDone() throws {
        var progress = JourneyProgressState.initial
        progress.completeAllStages()

        let allStageIDs = Set(GameContent.chapters.flatMap(\.stages).map(\.id))
        let lastStage = try #require(GameContent.chapters.flatMap(\.stages).last)
        try #expect(progress.completedStageIDs == allStageIDs)
        try #expect(progress.claimedRewardStageIDs == allStageIDs)
        try #expect(progress.activeStageID == nil)
        try #expect(progress.activeChapterID == lastStage.chapterID)
    }

    @Test func journeyPersistsProgress() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JourneyProgressTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let firstSaveStore = try SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        try firstSaveStore.performBatchMutation { save in
            save.journey.complete(chapter.stages[0], in: GameContent.chapters)
        }

        let secondSaveStore = try SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        try #expect(secondSaveStore.journey.activeStageID == "chapter-1-stage-2")
        try #expect(secondSaveStore.journey.completedStageIDs.contains("chapter-1-stage-1"))
    }

    @Test func journeyPersistsPinnedMysteryEventIDs() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JourneyPinTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let event = try #require(GameContent.mysteryEvent(matching: "mana-berries"))
        let firstSaveStore = try SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        try firstSaveStore.performBatchMutation { save in
            save.journey.pinnedMysteryEventIDs["chapter-1-stage-5"] = event.id
        }

        let secondSaveStore = try SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        try #expect(
            secondSaveStore.journey.pinnedMysteryEventIDs["chapter-1-stage-5"] == event.id
        )
    }

    @Test func startupRepairsDuplicateJourneyStageRows() throws {
        let directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "JourneyDuplicateStageTests")
        defer { SaveTestSupport.removeTempDirectory(directoryURL) }
        let storeURL = SaveTestSupport.makeStoreURL(directoryURL: directoryURL)
        let stageID = "chapter-1-stage-5"
        let eventID = try #require(GameContent.mysteryEvent(matching: "mana-berries")?.id)

        do {
            _ = try SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        }
        do {
            let context = try SaveTestSupport.makeSideContext(storeURL: storeURL)
            let journey = try #require(context.fetch(FetchDescriptor<JourneyProgressModel>()).first)
            let completed = JourneyStageProgressModel(
                stageID: stageID,
                isCompleted: true,
                mysteryEventID: eventID
            )
            let claimed = JourneyStageProgressModel(
                stageID: stageID,
                rewardsClaimed: true,
                mysteryEventID: eventID
            )
            completed.journey = journey
            claimed.journey = journey
            journey.stages = [completed, claimed]
            context.insert(completed)
            context.insert(claimed)
            try context.save()
        }

        let repairedStore = try SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
        try #expect(repairedStore.journey.completedStageIDs.contains(stageID))
        try #expect(repairedStore.journey.claimedRewardStageIDs.contains(stageID))
        try #expect(repairedStore.journey.pinnedMysteryEventIDs[stageID] == eventID)

        let context = try SaveTestSupport.makeSideContext(storeURL: storeURL)
        let stageRows = try context.fetch(FetchDescriptor<JourneyStageProgressModel>())
        try #expect(stageRows.count(where: { $0.stageID == stageID }) == 1)
    }
}
