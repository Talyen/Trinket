import XCTest
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

    private func makeContext(
        roster: PlayerRosterState = .initial,
        inventory: PlayerInventoryState = PlayerInventoryState(items: []),
        homestead: PlayerHomesteadState = .freshStart,
        journey: JourneyProgressState = .initial
    ) -> StageCompletionContext {
        StageCompletionContext(
            roster: roster,
            inventory: inventory,
            homestead: homestead,
            journey: journey
        )
    }

    func testCompletingStageGrantsBattleGoldWithStageRewards() throws {
        var context = makeContext()
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            battleEarnedGold: 4,
            in: GameContent.chapters,
            context: &context
        )

        XCTAssertEqual(context.roster.gold, firstStage.rewards.gold + 4)
    }

    func testCompletingStageGrantsGoldXPAndItems() throws {
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        var context = makeContext()

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            context: &context
        )

        XCTAssertEqual(context.roster.gold, firstStage.rewards.gold)
        let encounterLevel = EncounterLevelResolver.journeyEnemyLevel(for: firstStage, in: chapter)
        let heroLevel = PlayerRosterState.initial.progression(for: hero).level
        let petLevel = PlayerRosterState.initial.progression(for: pet).level
        let expectedHeroProgression = PlayerRosterState.initial.progression(for: hero).addingExperience(
            ExperienceScaling.battleAwardWithCatchUp(
                playerLevel: heroLevel,
                enemyLevel: encounterLevel,
                highestLevel: PlayerRosterState.initial.highestHeroLevel
            )
        )
        let expectedPetProgression = PlayerRosterState.initial.progression(for: pet).addingExperience(
            ExperienceScaling.battleAwardWithCatchUp(
                playerLevel: petLevel,
                enemyLevel: encounterLevel,
                highestLevel: PlayerRosterState.initial.highestPetLevel
            )
        )
        XCTAssertEqual(context.roster.progression(for: hero), expectedHeroProgression)
        XCTAssertEqual(context.roster.progression(for: pet), expectedPetProgression)
        _ = try XCTUnwrap(context.inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        XCTAssertEqual(context.homestead.resources[.wood], 8)
        XCTAssertEqual(context.homestead.resources[.stone], 3)
        XCTAssertTrue(context.journey.hasClaimedRewards(for: firstStage))
        XCTAssertTrue(context.journey.isCompleted(firstStage))
        XCTAssertEqual(context.journey.activeStageID, "chapter-1-stage-2")
    }

    func testHomesteadBonusesAdjustMaterialRewards() throws {
        var context = makeContext(
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wheatField: 3]
            )
        )
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            context: &context
        )

        XCTAssertEqual(context.homestead.resources[.wood], 9)
        XCTAssertEqual(context.homestead.resources[.stone], 4)
    }

    func testHomesteadFoodBonusesStackFromMultipleBuildings() throws {
        var context = makeContext(
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wheatField: 2, .chickenCoop: 2]
            )
        )
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
                itemTemplateIDs: [],
                materialRewards: [ResourceAmount(.food, 4)]
            )
        )

        StageCompletion.claimRewardsIfNeeded(
            for: foodStage,
            hero: hero,
            pet: pet,
            context: &context
        )

        XCTAssertEqual(context.homestead.resources[.food], 6)
    }

    func testCompletingStageTwiceDoesNotDoubleRewards() throws {
        var context = makeContext()
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            context: &context
        )
        let goldAfterFirst = context.roster.gold
        let heroXPAfterFirst = context.roster.progression(for: hero).currentXP
        let itemCountAfterFirst = context.inventory.items.count

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            context: &context
        )

        XCTAssertEqual(context.roster.gold, goldAfterFirst)
        XCTAssertEqual(context.roster.progression(for: hero).currentXP, heroXPAfterFirst)
        XCTAssertEqual(context.inventory.items.count, itemCountAfterFirst)
    }

    func testCompletingStageTwiceDoesNotAdvanceJourney() throws {
        var context = makeContext()
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            context: &context
        )
        let activeStageAfterFirst = context.journey.activeStageID

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            context: &context
        )

        XCTAssertEqual(context.journey.activeStageID, activeStageAfterFirst)
    }

    func testCompletingStageAdvancesJourney() throws {
        var context = makeContext(inventory: .initial)
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            context: &context
        )

        XCTAssertTrue(context.journey.isActive(chapter.stages[1]))
        XCTAssertFalse(context.journey.isActive(firstStage))
    }

    func testMissingItemTemplateSkipsGracefully() throws {
        var context = makeContext()
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let heroXPBefore = context.roster.progression(for: hero).currentXP
        let stageWithBadTemplate = Stage(
            id: "test-stage",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            flavorText: "Test",
            encounter: .event,
            rewards: StageReward(gold: 10, itemTemplateIDs: ["missing-template"])
        )

        StageCompletion.claimRewardsIfNeeded(
            for: stageWithBadTemplate,
            hero: hero,
            pet: pet,
            context: &context,
            resolveTemplate: { _ in nil }
        )

        XCTAssertEqual(context.roster.gold, 10)
        XCTAssertEqual(context.roster.progression(for: hero).currentXP, heroXPBefore)
        XCTAssertTrue(context.inventory.items.isEmpty)
        XCTAssertTrue(context.journey.hasClaimedRewards(for: stageWithBadTemplate))
    }

    func testNonBattleStagesGrantNoExperience() throws {
        var context = makeContext()
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let heroXPBefore = context.roster.progression(for: hero).currentXP
        let eventStage = chapter.stages[1]

        StageCompletion.claimRewardsIfNeeded(
            for: eventStage,
            hero: hero,
            pet: pet,
            context: &context
        )

        XCTAssertEqual(context.roster.progression(for: hero).currentXP, heroXPBefore)
    }

    func testScaledExperienceGrantsNothingWhenEnemyIsFarBelowPlayer() throws {
        var context = makeContext()
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        context.roster.progressions[hero.id] = CombatantProgression(level: 20, currentXP: 0, requiredXP: 500)
        let heroXPBefore = context.roster.progression(for: hero).currentXP

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            enemyEncounterLevel: 5,
            context: &context
        )

        XCTAssertEqual(context.roster.progression(for: hero).currentXP, heroXPBefore)
        XCTAssertGreaterThan(context.roster.progression(for: pet).currentXP, 0)
    }

    func testClaimRewardsIfNeededIsIdempotentWhenCalledTwice() throws {
        var context = makeContext()
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            battleEarnedGold: 9,
            context: &context
        )
        let goldAfterFirstClaim = context.roster.gold
        let heroXPAfterFirstClaim = context.roster.progression(for: hero).currentXP
        let itemCountAfterFirstClaim = context.inventory.items.count

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            battleEarnedGold: 9,
            context: &context
        )

        XCTAssertEqual(context.roster.gold, goldAfterFirstClaim)
        XCTAssertEqual(context.roster.progression(for: hero).currentXP, heroXPAfterFirstClaim)
        XCTAssertEqual(context.inventory.items.count, itemCountAfterFirstClaim)
        XCTAssertTrue(context.journey.hasClaimedRewards(for: firstStage))
    }

    func testRewardItemPreservesCatalogAffixes() throws {
        let template = try XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic"))
        var inventory = PlayerInventoryState(items: [])
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 999)

        inventory.addRewardItem(from: template, for: firstStage, using: &randomNumberGenerator)

        let rewardItem = try XCTUnwrap(inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        XCTAssertEqual(rewardItem.affixes, template.affixes)
    }

    func testClaimRewardsUsesPrecomputedMaterialRewards() throws {
        var context = makeContext(
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wheatField: 2, .chickenCoop: 2]
            )
        )
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let snapshot = [ResourceAmount(.food, 4)]

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            materialRewards: snapshot,
            context: &context
        )

        XCTAssertEqual(context.homestead.resources[.food], 4)
    }
}
