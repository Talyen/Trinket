import XCTest
@testable import Trinket

final class JourneyProgressTests: XCTestCase {
    private var chapter: Chapter { GameContent.chapters[0] }

    func testCompletingStageUnlocksExactlyNextStage() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        let secondStage = chapter.stages[1]
        let thirdStage = chapter.stages[2]

        progress.complete(firstStage, in: GameContent.chapters)

        XCTAssertTrue(progress.isCompleted(firstStage))
        XCTAssertTrue(progress.isActive(secondStage))
        XCTAssertFalse(progress.isActive(firstStage))
        XCTAssertFalse(progress.isActive(thirdStage))
    }

    func testCompletedAndFutureStagesAreNotActive() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        let secondStage = chapter.stages[1]
        let finalStage = chapter.stages[9]

        progress.complete(firstStage, in: GameContent.chapters)

        XCTAssertTrue(progress.isCompleted(firstStage))
        XCTAssertFalse(progress.isActive(firstStage))
        XCTAssertTrue(progress.isActive(secondStage))
        XCTAssertFalse(progress.isActive(finalStage))
    }

    func testRewardsCanOnlyBeClaimedOncePerStage() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]

        XCTAssertFalse(progress.hasClaimedRewards(for: firstStage))
        progress.markRewardsClaimed(for: firstStage)
        progress.markRewardsClaimed(for: firstStage)

        XCTAssertTrue(progress.hasClaimedRewards(for: firstStage))
        XCTAssertEqual(progress.claimedRewardStageIDs.count, 1)
    }

    func testExperienceAppliesToActiveParty() {
        var roster = PlayerRosterState.initial
        let hero = GameContent.heroes[0]
        let pet = GameContent.pets[0]
        let heroBefore = roster.progression(for: hero).currentXP
        let petBefore = roster.progression(for: pet).currentXP

        roster.grantExperience(20, to: hero)
        roster.grantExperience(20, to: pet)

        XCTAssertEqual(roster.progression(for: hero).currentXP, heroBefore + 20)
        XCTAssertEqual(roster.progression(for: pet).currentXP, petBefore + 20)
    }

    func testItemRewardCreatesUniqueInstance() throws {
        var inventory = PlayerInventoryState.initial
        let stage = chapter.stages[0]
        let template = try XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic"))
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 7)

        inventory.addRewardItem(from: template, for: stage, using: &randomNumberGenerator)

        let rewardItem = try XCTUnwrap(inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        XCTAssertEqual(rewardItem.templateID, "shortsword-basic")
        XCTAssertNotEqual(rewardItem.id, rewardItem.templateID)
        XCTAssertTrue((1...2).contains(rewardItem.affixes.count))
    }

    func testChapterCompletionExposesLockedNextChapterState() {
        var progress = JourneyProgressState.initial

        for stage in chapter.stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        XCTAssertNil(progress.activeStageID)
        XCTAssertEqual(progress.lastCompletedStageID, "chapter-1-stage-10")
    }

    func testJourneyStorePersistsProgress() throws {
        let suiteName = "JourneyProgressTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = PlayerJourneyStore(defaults: defaults)
        firstStore.complete(chapter.stages[0], in: GameContent.chapters)

        let secondStore = PlayerJourneyStore(defaults: defaults)
        XCTAssertEqual(secondStore.current.activeStageID, "chapter-1-stage-2")
        XCTAssertTrue(secondStore.current.completedStageIDs.contains("chapter-1-stage-1"))
    }
}
