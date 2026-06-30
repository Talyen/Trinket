@testable import Trinket
import XCTest

final class StageRewardTests: XCTestCase {
    private var chapter: Chapter { GameContent.chapters[0] }
    private var firstStage: Stage { chapter.stages[0] }

    func testCompletingStageGrantsGoldXPAndItems() throws {
        var roster = PlayerRosterState.initial
        var inventory = PlayerInventoryState(items: [])
        var journey = JourneyProgressState.initial
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let heroXPBefore = roster.progression(for: hero).currentXP
        let petXPBefore = roster.progression(for: pet).currentXP

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            roster: &roster,
            inventory: &inventory,
            journey: &journey
        )

        XCTAssertEqual(roster.gold, firstStage.rewards.gold)
        XCTAssertEqual(roster.progression(for: hero).currentXP, heroXPBefore + firstStage.rewards.experience)
        XCTAssertEqual(roster.progression(for: pet).currentXP, petXPBefore + firstStage.rewards.experience)
        XCTAssertNotNil(inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        XCTAssertTrue(journey.hasClaimedRewards(for: firstStage))
        XCTAssertTrue(journey.isCompleted(firstStage))
        XCTAssertEqual(journey.activeStageID, "chapter-1-stage-2")
    }

    func testCompletingStageTwiceDoesNotDoubleRewards() throws {
        var roster = PlayerRosterState.initial
        var inventory = PlayerInventoryState(items: [])
        var journey = JourneyProgressState.initial
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            roster: &roster,
            inventory: &inventory,
            journey: &journey
        )
        let goldAfterFirst = roster.gold
        let heroXPAfterFirst = roster.progression(for: hero).currentXP
        let itemCountAfterFirst = inventory.items.count

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            roster: &roster,
            inventory: &inventory,
            journey: &journey
        )

        XCTAssertEqual(roster.gold, goldAfterFirst)
        XCTAssertEqual(roster.progression(for: hero).currentXP, heroXPAfterFirst)
        XCTAssertEqual(inventory.items.count, itemCountAfterFirst)
    }

    func testCompletingStageAdvancesJourney() throws {
        var roster = PlayerRosterState.initial
        var inventory = PlayerInventoryState.initial
        var journey = JourneyProgressState.initial
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            roster: &roster,
            inventory: &inventory,
            journey: &journey
        )

        XCTAssertTrue(journey.isActive(chapter.stages[1]))
        XCTAssertFalse(journey.isActive(firstStage))
    }

    func testMissingItemTemplateSkipsGracefully() throws {
        var roster = PlayerRosterState.initial
        var inventory = PlayerInventoryState(items: [])
        var journey = JourneyProgressState.initial
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let heroXPBefore = roster.progression(for: hero).currentXP
        let stageWithBadTemplate = Stage(
            id: "test-stage",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            title: "Test",
            flavorText: "Test",
            encounter: .event,
            rewards: StageReward(gold: 10, experience: 15, itemTemplateIDs: ["missing-template"])
        )

        StageCompletion.claimRewardsIfNeeded(
            for: stageWithBadTemplate,
            hero: hero,
            pet: pet,
            roster: &roster,
            inventory: &inventory,
            journey: &journey,
            resolveTemplate: { _ in nil }
        )

        XCTAssertEqual(roster.gold, 10)
        XCTAssertEqual(roster.progression(for: hero).currentXP, heroXPBefore + 15)
        XCTAssertTrue(inventory.items.isEmpty)
        XCTAssertTrue(journey.hasClaimedRewards(for: stageWithBadTemplate))
    }
}
