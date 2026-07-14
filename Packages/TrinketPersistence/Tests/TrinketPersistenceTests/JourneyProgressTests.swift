import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
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
    }

    @Test func completedAndFutureStagesAreNotActive() throws {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        let secondStage = chapter.stages[1]
        let finalStage = chapter.stages[4]

        progress.complete(firstStage, in: GameContent.chapters)

        try #expect(progress.isCompleted(firstStage))
        try #expect(!(progress.isActive(firstStage)))
        try #expect(progress.isActive(secondStage))
        try #expect(!(progress.isActive(finalStage)))
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

    @Test func experienceAppliesToActiveParty() throws {
        var roster = PlayerRosterState.initial
        let hero = GameContent.heroes[0]
        let companion = GameContent.companions[0]
        let heroBefore = roster.progression(for: hero).currentXP
        let companionBefore = roster.progression(for: companion).currentXP

        roster.grantExperience(20, to: hero)
        roster.grantExperience(20, to: companion)

        try #expect(roster.progression(for: hero).currentXP == heroBefore + 20)
        try #expect(roster.progression(for: companion).currentXP == companionBefore + 20)
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

    @Test func chapterCompletionParksUntilAdvanceToNextChapter() throws {
        var progress = JourneyProgressState.initial

        for stage in chapter.stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        try #expect(progress.activeStageID == nil)
        try #expect(progress.activeChapterID == "chapter-1")
        try #expect(progress.lastCompletedStageID == "chapter-1-stage-5")
        try #expect(progress.pendingNextChapter()?.id == "chapter-2")

        let advanced = progress.advanceToNextChapter()
        try #expect(advanced)
        try #expect(progress.activeStageID == "chapter-2-stage-1")
        try #expect(progress.activeChapterID == "chapter-2")
        try #expect(progress.pendingNextChapter() == nil)
    }

    @Test func completeChapterMarksOnlyThatChapterDone() throws {
        var progress = JourneyProgressState.initial
        progress.completeChapter("chapter-1")

        let chapter1 = try #require(GameContent.chapters.first { $0.id == "chapter-1" })
        let chapter1StageIDs = Set(chapter1.stages.map(\.id))
        let lastStage = try #require(chapter1.stages.last)
        try #expect(progress.completedStageIDs == chapter1StageIDs)
        try #expect(progress.claimedRewardStageIDs == chapter1StageIDs)
        try #expect(progress.activeStageID == nil)
        try #expect(progress.activeChapterID == "chapter-1")
        try #expect(progress.lastCompletedStageID == lastStage.id)
        try #expect(progress.isActiveChapterCleared())
        if GameContent.chapters.count > 1 {
            try #expect(progress.pendingNextChapter()?.id == "chapter-2")
        }
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
        try #expect(progress.lastCompletedStageID == lastStage.id)
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
}
