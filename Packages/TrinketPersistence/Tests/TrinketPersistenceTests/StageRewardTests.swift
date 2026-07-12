import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct StageRewardTests {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    private var firstStage: Stage {
        chapter.stages[0]
    }

    private func makeSave(
        roster: PlayerRosterState = .initial,
        inventory: PlayerInventoryState = PlayerInventoryState(items: []),
        homestead: PlayerHomesteadState = .freshStart,
        journey: JourneyProgressState = .initial
    ) -> PlayerSave {
        PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            journey: journey,
            roster: roster,
            inventory: inventory,
            homestead: homestead
        )
    }

    @Test func completingStageGrantsBattleGoldWithStageRewards() throws {
        var save = makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            battleEarnedGold: 4,
            in: GameContent.chapters,
            save: &save
        )

        try #expect(save.roster.gold == firstStage.rewards.gold + 4)
    }

    @Test func completingStageGrantsGoldXPAndItems() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
        var save = makeSave()

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            save: &save
        )

        try #expect(save.roster.gold == firstStage.rewards.gold)
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
        try #expect(save.roster.progression(for: hero) == expectedHeroProgression)
        try #expect(save.roster.progression(for: pet) == expectedPetProgression)
        _ = try #require(save.inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        try #expect(save.homestead.resources[.wood] == 8)
        try #expect(save.homestead.resources[.stone] == 3)
        try #expect(save.journey.hasClaimedRewards(for: firstStage))
        try #expect(save.journey.isCompleted(firstStage))
        try #expect(save.journey.activeStageID == "chapter-1-stage-2")
    }

    @Test func materialRewardsAreUnchangedByHomesteadTiers() throws {
        var save = makeSave(
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
            save: &save
        )

        try #expect(save.homestead.resources[.wood] == 8)
        try #expect(save.homestead.resources[.stone] == 3)
    }

    @Test func wishingWellIncreasesGrantedGold() throws {
        var save = makeSave(
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wishingWell: 2]
            )
        )
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
        let startingGold = save.roster.gold

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            battleEarnedGold: 0,
            save: &save
        )

        let expected = startingGold + HomesteadEffects.from(nodeTiers: [.wishingWell: 2])
            .adjustedGold(firstStage.rewards.gold)
        try #expect(save.roster.gold == expected)
    }

    @Test func completingStageTwiceDoesNotDoubleRewards() throws {
        var save = makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            save: &save
        )
        let goldAfterFirst = save.roster.gold
        let heroXPAfterFirst = save.roster.progression(for: hero).currentXP
        let itemCountAfterFirst = save.inventory.items.count

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            save: &save
        )

        try #expect(save.roster.gold == goldAfterFirst)
        try #expect(save.roster.progression(for: hero).currentXP == heroXPAfterFirst)
        try #expect(save.inventory.items.count == itemCountAfterFirst)
    }

    @Test func completingStageTwiceDoesNotAdvanceJourney() throws {
        var save = makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            save: &save
        )
        let activeStageAfterFirst = save.journey.activeStageID

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            save: &save
        )

        try #expect(save.journey.activeStageID == activeStageAfterFirst)
    }

    @Test func completingStageAdvancesJourney() throws {
        var save = makeSave(inventory: .initial)
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            pet: pet,
            in: GameContent.chapters,
            save: &save
        )

        try #expect(save.journey.isActive(chapter.stages[1]))
        try #expect(!(save.journey.isActive(firstStage)))
    }

    @Test func missingItemTemplateSkipsGracefully() throws {
        var save = makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
        let heroXPBefore = save.roster.progression(for: hero).currentXP
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
            save: &save,
            resolveTemplate: { _ in nil }
        )

        try #expect(save.roster.gold == 10)
        try #expect(save.roster.progression(for: hero).currentXP == heroXPBefore)
        try #expect(save.inventory.items.isEmpty)
        try #expect(save.journey.hasClaimedRewards(for: stageWithBadTemplate))
    }

    @Test func nonBattleStagesGrantNoExperience() throws {
        var save = makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
        let heroXPBefore = save.roster.progression(for: hero).currentXP
        let eventStage = chapter.stages[1]

        StageCompletion.claimRewardsIfNeeded(
            for: eventStage,
            hero: hero,
            pet: pet,
            save: &save
        )

        try #expect(save.roster.progression(for: hero).currentXP == heroXPBefore)
    }

    @Test func scaledExperienceGrantsNothingWhenEnemyIsFarBelowPlayer() throws {
        var save = makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
        save.roster.progressions[hero.id] = CombatantProgression(level: 20, currentXP: 0, requiredXP: 500)
        let heroXPBefore = save.roster.progression(for: hero).currentXP

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            enemyEncounterLevel: 5,
            save: &save
        )

        try #expect(save.roster.progression(for: hero).currentXP == heroXPBefore)
        try #expect(save.roster.progression(for: pet).currentXP > 0)
    }

    @Test func claimRewardsIfNeededIsIdempotentWhenCalledTwice() throws {
        var save = makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            battleEarnedGold: 9,
            save: &save
        )
        let goldAfterFirstClaim = save.roster.gold
        let heroXPAfterFirstClaim = save.roster.progression(for: hero).currentXP
        let itemCountAfterFirstClaim = save.inventory.items.count

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            battleEarnedGold: 9,
            save: &save
        )

        try #expect(save.roster.gold == goldAfterFirstClaim)
        try #expect(save.roster.progression(for: hero).currentXP == heroXPAfterFirstClaim)
        try #expect(save.inventory.items.count == itemCountAfterFirstClaim)
        try #expect(save.journey.hasClaimedRewards(for: firstStage))
    }

    @Test func rewardItemPreservesCatalogAffixes() throws {
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        var inventory = PlayerInventoryState(items: [])
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 999)

        inventory.addRewardItem(from: template, for: firstStage, using: &randomNumberGenerator)

        let rewardItem = try #require(inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        try #expect(rewardItem.affixes == template.affixes)
    }

    @Test func claimRewardsUsesPrecomputedMaterialRewards() throws {
        var save = makeSave(
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
            save: &save
        )

        try #expect(save.homestead.resources[.food] == 4)
    }
}
