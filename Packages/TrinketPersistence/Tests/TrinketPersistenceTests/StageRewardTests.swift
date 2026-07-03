import XCTest
import BattleEngine
import TrinketCore
import TrinketContent
@testable import TrinketPersistence

final class StageRewardTests: XCTestCase {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    private var firstStage: Stage {
        chapter.stages[0]
    }

    func testCompletingStageGrantsBattleGoldWithStageRewards() throws {
        var roster = PlayerRosterState.initial
        var inventory = PlayerInventoryState(items: [])
        var journey = JourneyProgressState.initial
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            battleEarnedGold: 4,
            in: GameContent.chapters,
            roster: &roster,
            inventory: &inventory,
            journey: &journey
        )

        XCTAssertEqual(roster.gold, firstStage.rewards.gold + 4)
    }

    func testCompletingStageGrantsGoldXPAndItems() throws {
        var roster = PlayerRosterState.initial
        var inventory = PlayerInventoryState(items: [])
        var homestead = PlayerHomesteadState.freshStart
        var journey = JourneyProgressState.initial
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let heroXPBefore = roster.progression(for: hero).currentXP
        let petXPBefore = roster.progression(for: pet).currentXP

        var ctx = StageCompletionContext(
            roster: roster,
            inventory: inventory,
            homestead: homestead,
            journey: journey
        )
        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            context: &ctx
        )
        roster = ctx.roster
        inventory = ctx.inventory
        homestead = ctx.homestead
        journey = ctx.journey

        XCTAssertEqual(roster.gold, firstStage.rewards.gold)
        XCTAssertEqual(roster.progression(for: hero).currentXP, heroXPBefore + firstStage.rewards.experience)
        XCTAssertEqual(roster.progression(for: pet).currentXP, petXPBefore + firstStage.rewards.experience)
        XCTAssertNotNil(inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        XCTAssertEqual(homestead.resources[.wood], 8)
        XCTAssertEqual(homestead.resources[.stone], 3)
        XCTAssertTrue(journey.hasClaimedRewards(for: firstStage))
        XCTAssertTrue(journey.isCompleted(firstStage))
        XCTAssertEqual(journey.activeStageID, "chapter-1-stage-2")
    }

    func testHomesteadBonusesAdjustMaterialRewards() throws {
        var roster = PlayerRosterState.initial
        var inventory = PlayerInventoryState(items: [])
        var homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 3]
        )
        var journey = JourneyProgressState.initial
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            roster: &roster,
            inventory: &inventory,
            homestead: &homestead,
            journey: &journey
        )

        XCTAssertEqual(homestead.resources[.wood], 9)
        XCTAssertEqual(homestead.resources[.stone], 4)
    }

    func testHomesteadFoodBonusUsesFirstMatchingNodeRule() throws {
        var roster = PlayerRosterState.initial
        var inventory = PlayerInventoryState(items: [])
        var homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 2, .chickenCoop: 2]
        )
        var journey = JourneyProgressState.initial
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let foodStage = Stage(
            id: "food-test-stage",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            flavorText: "Test",
            encounter: .event,
            rewards: StageReward(
                gold: 0,
                experience: 0,
                itemTemplateIDs: [],
                materialRewards: [ResourceAmount(.food, 4)]
            )
        )

        StageCompletion.claimRewardsIfNeeded(
            for: foodStage,
            hero: hero,
            pet: pet,
            roster: &roster,
            inventory: &inventory,
            homestead: &homestead,
            journey: &journey
        )

        XCTAssertEqual(homestead.resources[.food], 5)
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
