import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct StageRewardTests {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    private var firstStage: Stage {
        chapter.stages[0]
    }

    @Test func `completing battle stage grants battle loot gold XP and item`() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        var save = SaveTestSupport.makeSave()
        let battleEarnedGold = 4
        let encounterLevel = EncounterLevelResolver.journeyEnemyLevel(for: firstStage, in: chapter)
        let loot = BattleLoot.resolveJourney(
            stage: firstStage,
            encounterLevel: encounterLevel,
            enemyIsBoss: false,
            worldSeed: PlayerSave.testWorldSeed,
            ownedTrinketIDs: [],
            ownedUniqueIDs: [],
        )

        StageCompletion.complete(
            firstStage,
            hero: hero,
            companion: companion,
            battleEarnedGold: battleEarnedGold,
            loot: loot,
            in: GameContent.chapters,
            save: &save,
        )

        try #expect(save.roster.gold == loot.gold + battleEarnedGold)
        let heroLevel = PlayerRosterState.testSeed.progression(for: hero).level
        let companionLevel = PlayerRosterState.testSeed.progression(for: companion).level
        let expectedHeroProgression = PlayerRosterState.testSeed.progression(for: hero).addingExperience(
            StageCompletion.battleExperienceAward(
                playerLevel: heroLevel,
                enemyLevel: encounterLevel,
                highestLevel: PlayerRosterState.testSeed.highestHeroLevel,
            ),
        )
        let expectedCompanionProgression = PlayerRosterState.testSeed.progression(for: companion).addingExperience(
            StageCompletion.battleExperienceAward(
                playerLevel: companionLevel,
                enemyLevel: encounterLevel,
                highestLevel: PlayerRosterState.testSeed.highestCompanionLevel,
            ),
        )
        try #expect(save.roster.progression(for: hero) == expectedHeroProgression)
        try #expect(save.roster.progression(for: companion) == expectedCompanionProgression)
        _ = try #require(save.inventory.item(matching: loot.item.id))
        try #expect(loot.materials.count == 2)
        for material in loot.materials {
            try #expect(save.homestead.resources[material.resource] == material.quantity)
        }
        try #expect(save.journey.hasClaimedRewards(for: firstStage))
        try #expect(save.journey.isCompleted(firstStage))
        try #expect(save.journey.activeStageID == "chapter-1-stage-2")
    }

    @Test func `wishing well increases granted gold`() throws {
        var save = SaveTestSupport.makeSave(
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wishingWell: 2],
            ),
        )
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let startingGold = save.roster.gold
        let encounterLevel = EncounterLevelResolver.journeyEnemyLevel(for: firstStage, in: chapter)
        let loot = BattleLoot.resolveJourney(
            stage: firstStage,
            encounterLevel: encounterLevel,
            enemyIsBoss: false,
            worldSeed: PlayerSave.testWorldSeed,
            ownedTrinketIDs: [],
            ownedUniqueIDs: [],
        )

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            companion: companion,
            battleEarnedGold: 0,
            loot: loot,
            save: &save,
        )

        let expected = startingGold + HomesteadEffects.from(nodeTiers: [.wishingWell: 2])
            .adjustedGold(loot.gold)
        try #expect(save.roster.gold == expected)
    }

    @Test func `completing stage twice does not double rewards`() throws {
        var save = SaveTestSupport.makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            companion: companion,
            in: GameContent.chapters,
            save: &save,
        )
        let goldAfterFirst = save.roster.gold
        let heroXPAfterFirst = save.roster.progression(for: hero).currentXP
        let itemCountAfterFirst = save.inventory.items.count

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            companion: companion,
            save: &save,
        )

        try #expect(save.roster.gold == goldAfterFirst)
        try #expect(save.roster.progression(for: hero).currentXP == heroXPAfterFirst)
        try #expect(save.inventory.items.count == itemCountAfterFirst)
    }

    @Test func `claimed stage replay still banks battle earned gold`() throws {
        var save = SaveTestSupport.makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let loot = BattleLoot.resolveJourney(
            stage: firstStage,
            encounterLevel: EncounterLevelResolver.journeyEnemyLevel(for: firstStage, in: chapter),
            enemyIsBoss: false,
            worldSeed: PlayerSave.testWorldSeed,
            ownedTrinketIDs: [],
            ownedUniqueIDs: [],
        )

        StageCompletion.complete(
            firstStage,
            hero: hero,
            companion: companion,
            battleEarnedGold: 4,
            loot: loot,
            in: GameContent.chapters,
            save: &save,
        )
        let goldAfterFirst = save.roster.gold

        StageCompletion.complete(
            firstStage,
            hero: hero,
            companion: companion,
            battleEarnedGold: 2,
            loot: loot,
            in: GameContent.chapters,
            save: &save,
        )

        try #expect(save.roster.gold == goldAfterFirst)
        try #expect(save.inventory.items.count(where: { $0.id == loot.item.id }) == 1)
    }

    @Test func `completing stage advances journey`() throws {
        var save = SaveTestSupport.makeSave(inventory: .testSeed)
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })

        StageCompletion.complete(
            firstStage,
            hero: hero,
            companion: companion,
            in: GameContent.chapters,
            save: &save,
        )

        try #expect(save.journey.isActive(chapter.stages[1]))
        try #expect(!(save.journey.isActive(firstStage)))
    }

    @Test func `non battle stages grant authored rewards without experience`() throws {
        var save = SaveTestSupport.makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let heroXPBefore = save.roster.progression(for: hero).currentXP
        let restStage = Stage(
            id: "test-rest",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            encounter: .rest,
            rewards: StageReward(gold: 10, itemTemplateIDs: [], materialRewards: [ResourceAmount(.wood, 2)]),
        )

        StageCompletion.claimRewardsIfNeeded(
            for: restStage,
            hero: hero,
            companion: companion,
            save: &save,
        )

        try #expect(save.roster.gold == 10)
        try #expect(save.homestead.resources[.wood] == 2)
        try #expect(save.roster.progression(for: hero).currentXP == heroXPBefore)
        try #expect(save.journey.hasClaimedRewards(for: restStage))
    }

    @Test func `scaled experience grants nothing when enemy is far below player`() throws {
        var save = SaveTestSupport.makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        save.roster.progressions[hero.id] = CombatantProgression(level: 20, currentXP: 0, requiredXP: 500)
        let heroXPBefore = save.roster.progression(for: hero).currentXP

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            companion: companion,
            enemyEncounterLevel: 5,
            save: &save,
        )

        try #expect(save.roster.progression(for: hero).currentXP == heroXPBefore)
        try #expect(save.roster.progression(for: companion).currentXP > 0)
    }

    @Test func `stage completion prefers provided enemy level over authored derivation`() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let battleStages = GameContent.chapters.flatMap(\.stages).filter(\.encounter.isCombat)
        let deepStage = try #require(
            battleStages.last {
                StageCompletion.resolvedEncounterLevel(for: $0, in: GameContent.chapters) > 3
            },
        )

        var defaulted = SaveTestSupport.makeSave()
        defaulted.roster.progressions[hero.id] = .at(level: 10)
        StageCompletion.complete(
            deepStage,
            hero: hero,
            companion: companion,
            in: GameContent.chapters,
            save: &defaulted,
        )
        let defaultedHeroXP = defaulted.roster.progression(for: hero).currentXP

        var lowered = SaveTestSupport.makeSave()
        lowered.roster.progressions[hero.id] = .at(level: 10)
        StageCompletion.complete(
            deepStage,
            hero: hero,
            companion: companion,
            enemyEncounterLevel: 1,
            in: GameContent.chapters,
            save: &lowered,
        )
        let loweredHeroXP = lowered.roster.progression(for: hero).currentXP

        #expect(defaultedHeroXP > 0)
        #expect(loweredHeroXP > 0)
        #expect(loweredHeroXP < defaultedHeroXP)
    }

    @Test func `claim rewards banks battle gold when stage already claimed`() throws {
        var save = SaveTestSupport.makeSave(
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wishingWell: 2],
            ),
        )
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            companion: companion,
            battleEarnedGold: 0,
            save: &save,
        )
        let goldAfterClaim = save.roster.gold
        let heroXPAfterClaim = save.roster.progression(for: hero).currentXP
        let itemCountAfterClaim = save.inventory.items.count

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            companion: companion,
            battleEarnedGold: 9,
            save: &save,
        )

        try #expect(save.roster.gold == goldAfterClaim)
        try #expect(save.roster.progression(for: hero).currentXP == heroXPAfterClaim)
        try #expect(save.inventory.items.count == itemCountAfterClaim)
        try #expect(save.journey.hasClaimedRewards(for: firstStage))
    }

    @Test func `resolved gold reward does not go negative`() {
        #expect(
            StageCompletion.resolvedGoldReward(
                stageGold: 0,
                battleEarnedGold: -3,
                goldFindPercent: 0,
            ) == 0,
        )
        #expect(
            StageCompletion.resolvedGoldReward(
                stageGold: 10,
                battleEarnedGold: -3,
                goldFindPercent: 0,
            ) == 7,
        )
    }

    @Test func `claim rewards uses precomputed material rewards`() throws {
        var save = SaveTestSupport.makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let overrides = [ResourceAmount(.crystal, 7), ResourceAmount(.herbs, 2)]

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            companion: companion,
            materialRewards: overrides,
            save: &save,
        )

        try #expect(save.homestead.resources[.crystal] == 7)
        try #expect(save.homestead.resources[.herbs] == 2)
    }
}
