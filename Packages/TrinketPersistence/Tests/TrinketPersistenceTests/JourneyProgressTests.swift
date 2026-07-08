import Foundation
import Testing
import TrinketCore
import TrinketContent
@testable import TrinketPersistence

@Suite @MainActor
final class JourneyProgressTests {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    @Test func completingStageUnlocksExactlyNextStage() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        let secondStage = chapter.stages[1]
        let thirdStage = chapter.stages[2]

        progress.complete(firstStage, in: GameContent.chapters)

        #expect(progress.isCompleted(firstStage))
        #expect(progress.isActive(secondStage))
        #expect(!(progress.isActive(firstStage)))
        #expect(!(progress.isActive(thirdStage)))
    }

    @Test func completedAndFutureStagesAreNotActive() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        let secondStage = chapter.stages[1]
        let finalStage = chapter.stages[9]

        progress.complete(firstStage, in: GameContent.chapters)

        #expect(progress.isCompleted(firstStage))
        #expect(!(progress.isActive(firstStage)))
        #expect(progress.isActive(secondStage))
        #expect(!(progress.isActive(finalStage)))
    }

    @Test func rewardsCanOnlyBeClaimedOncePerStage() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]

        #expect(!(progress.hasClaimedRewards(for: firstStage)))
        progress.markRewardsClaimed(for: firstStage)
        progress.markRewardsClaimed(for: firstStage)

        #expect(progress.hasClaimedRewards(for: firstStage))
        #expect(progress.claimedRewardStageIDs.count == 1)
    }

    @Test func experienceAppliesToActiveParty() {
        var roster = PlayerRosterState.initial
        let hero = GameContent.heroes[0]
        let pet = GameContent.pets[0]
        let heroBefore = roster.progression(for: hero).currentXP
        let petBefore = roster.progression(for: pet).currentXP

        roster.grantExperience(20, to: hero)
        roster.grantExperience(20, to: pet)

        #expect(roster.progression(for: hero).currentXP == heroBefore + 20)
        #expect(roster.progression(for: pet).currentXP == petBefore + 20)
    }

    @Test func itemRewardCreatesUniqueInstance() throws {
        var inventory = PlayerInventoryState.initial
        let stage = chapter.stages[0]
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 7)

        inventory.addRewardItem(from: template, for: stage, using: &randomNumberGenerator)

        let rewardItem = try #require(inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        #expect(rewardItem.templateID == "shortsword-basic")
        #expect(rewardItem.id != rewardItem.templateID)
        #expect((1 ... 2).contains(rewardItem.affixes.count))
    }

    @Test func chapterCompletionExposesLockedNextChapterState() {
        var progress = JourneyProgressState.initial

        for stage in chapter.stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        #expect(progress.activeStageID == nil)
        #expect(progress.lastCompletedStageID == "chapter-1-stage-10")
    }

    @Test func journeyStorePersistsProgress() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JourneyProgressTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let storeURL = SaveTestSupport.makeStoreURL(directoryURL: directoryURL)
        let saveStore = PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        let firstStore = PlayerJourneyStore(saveStore: saveStore)
        firstStore.complete(chapter.stages[0], in: GameContent.chapters)

        let secondStore = PlayerJourneyStore(
            saveStore: PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        )
        #expect(secondStore.current.activeStageID == "chapter-1-stage-2")
        #expect(secondStore.current.completedStageIDs.contains("chapter-1-stage-1"))
    }
}
