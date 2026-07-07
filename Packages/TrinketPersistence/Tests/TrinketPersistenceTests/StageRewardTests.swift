import Testing
import TrinketCore
import TrinketContent
@testable import TrinketPersistence

@Suite
struct StageRewardTests {
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

    @Test func completingStageGrantsBattleGoldWithStageRewards() throws {
        var context = makeContext()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            battleEarnedGold: 4,
            in: GameContent.chapters,
            context: &context
        )

        #expect(context.roster.gold == firstStage.rewards.gold + 4)
    }

    @Test func completingStageGrantsGoldXPAndItems() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
        var context = makeContext()

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            context: &context
        )

        #expect(context.roster.gold == firstStage.rewards.gold)
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
        #expect(context.roster.progression(for: hero) == expectedHeroProgression)
        #expect(context.roster.progression(for: pet) == expectedPetProgression)
        _ = try #require(context.inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        #expect(context.homestead.resources[.wood] == 8)
        #expect(context.homestead.resources[.stone] == 3)
        #expect(context.journey.hasClaimedRewards(for: firstStage))
        #expect(context.journey.isCompleted(firstStage))
        #expect(context.journey.activeStageID == "chapter-1-stage-2")
    }

    @Test func homesteadBonusesAdjustMaterialRewards() throws {
        var context = makeContext(
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wheatField: 3]
            )
        )
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            context: &context
        )

        #expect(context.homestead.resources[.wood] == 9)
        #expect(context.homestead.resources[.stone] == 4)
    }

    @Test func homesteadFoodBonusesStackFromMultipleBuildings() throws {
        var context = makeContext(
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wheatField: 2, .chickenCoop: 2]
            )
        )
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
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

        #expect(context.homestead.resources[.food] == 6)
    }

    @Test func completingStageTwiceDoesNotDoubleRewards() throws {
        var context = makeContext()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })

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

        #expect(context.roster.gold == goldAfterFirst)
        #expect(context.roster.progression(for: hero).currentXP == heroXPAfterFirst)
        #expect(context.inventory.items.count == itemCountAfterFirst)
    }

    @Test func completingStageTwiceDoesNotAdvanceJourney() throws {
        var context = makeContext()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })

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

        #expect(context.journey.activeStageID == activeStageAfterFirst)
    }

    @Test func completingStageAdvancesJourney() throws {
        var context = makeContext(inventory: .initial)
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            context: &context
        )

        #expect(context.journey.isActive(chapter.stages[1]))
        #expect(!(context.journey.isActive(firstStage)))
    }

    @Test func missingItemTemplateSkipsGracefully() throws {
        var context = makeContext()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
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

        #expect(context.roster.gold == 10)
        #expect(context.roster.progression(for: hero).currentXP == heroXPBefore)
        #expect(context.inventory.items.isEmpty)
        #expect(context.journey.hasClaimedRewards(for: stageWithBadTemplate))
    }

    @Test func nonBattleStagesGrantNoExperience() throws {
        var context = makeContext()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
        let heroXPBefore = context.roster.progression(for: hero).currentXP
        let eventStage = chapter.stages[1]

        StageCompletion.claimRewardsIfNeeded(
            for: eventStage,
            hero: hero,
            pet: pet,
            context: &context
        )

        #expect(context.roster.progression(for: hero).currentXP == heroXPBefore)
    }

    @Test func scaledExperienceGrantsNothingWhenEnemyIsFarBelowPlayer() throws {
        var context = makeContext()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
        context.roster.progressions[hero.id] = CombatantProgression(level: 20, currentXP: 0, requiredXP: 500)
        let heroXPBefore = context.roster.progression(for: hero).currentXP

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            enemyEncounterLevel: 5,
            context: &context
        )

        #expect(context.roster.progression(for: hero).currentXP == heroXPBefore)
        #expect(context.roster.progression(for: pet).currentXP > 0)
    }

    @Test func claimRewardsIfNeededIsIdempotentWhenCalledTwice() throws {
        var context = makeContext()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })

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

        #expect(context.roster.gold == goldAfterFirstClaim)
        #expect(context.roster.progression(for: hero).currentXP == heroXPAfterFirstClaim)
        #expect(context.inventory.items.count == itemCountAfterFirstClaim)
        #expect(context.journey.hasClaimedRewards(for: firstStage))
    }

    @Test func rewardItemPreservesCatalogAffixes() throws {
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        var inventory = PlayerInventoryState(items: [])
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 999)

        inventory.addRewardItem(from: template, for: firstStage, using: &randomNumberGenerator)

        let rewardItem = try #require(inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        #expect(rewardItem.affixes == template.affixes)
    }

    @Test func claimRewardsUsesPrecomputedMaterialRewards() throws {
        var context = makeContext(
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wheatField: 2, .chickenCoop: 2]
            )
        )
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
        let snapshot = [ResourceAmount(.food, 4)]

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            materialRewards: snapshot,
            context: &context
        )

        #expect(context.homestead.resources[.food] == 4)
    }
}
