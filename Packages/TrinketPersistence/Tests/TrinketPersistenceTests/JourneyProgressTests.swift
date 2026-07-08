import Foundation
import Testing
import TrinketCore
import TrinketContent
@testable import TrinketPersistence
import TrinketTestSupport

@Suite @MainActor
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
        let finalStage = chapter.stages[9]

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
        let pet = GameContent.pets[0]
        let heroBefore = roster.progression(for: hero).currentXP
        let petBefore = roster.progression(for: pet).currentXP

        roster.grantExperience(20, to: hero)
        roster.grantExperience(20, to: pet)

        try #expect(roster.progression(for: hero).currentXP == heroBefore + 20)
        try #expect(roster.progression(for: pet).currentXP == petBefore + 20)
    }

    @Test func itemRewardCreatesUniqueInstance() throws {
        var inventory = PlayerInventoryState.initial
        let stage = chapter.stages[0]
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 7)

        inventory.addRewardItem(from: template, for: stage, using: &randomNumberGenerator)

        let rewardItem = try #require(inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        try #expect(rewardItem.templateID == "shortsword-basic")
        try #expect(rewardItem.id != rewardItem.templateID)
        try #expect((1 ... 2).contains(rewardItem.affixes.count))
    }

    @Test func chapterCompletionExposesLockedNextChapterState() throws {
        var progress = JourneyProgressState.initial

        for stage in chapter.stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        try #expect(progress.activeStageID == nil)
        try #expect(progress.lastCompletedStageID == "chapter-1-stage-10")
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
