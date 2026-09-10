import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct StageRewardTests {
    @Test @MainActor func `resolved award preserves gross gains spending and experience across reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let plan = BattleRewardPlan(
            stageGold: 10, goldFindPercent: 50, heroExperience: 4, companionExperience: 5, materials: [], items: [],
        )
        let award = plan.resolve(battleGold: .init(gained: 10, spent: 20))
        #expect(award.goldDelta == 10)
        let beforeHero = store.roster.progression(for: store.roster.activeHero)
        let beforeCompanion = store.roster.progression(for: store.roster.activeCompanion)
        try #require(store.persistBatch(logging: "Apply resolved award") { save in
            save.roster.gold = 100
            save.homestead.nodeTiers[.wishingWell] = 3
            save.homestead.lastProductionAt = Date()
            save.homestead.pendingProduction = [:]
            let settlement = plan.settle(
                battleGold: award.goldFlow,
                inputs: RewardSettlementInputs(save: save, hero: save.roster.activeHero, companion: save.roster.activeCompanion),
            )
            VictoryRewardApplier.apply(settlement, hero: save.roster.activeHero, companion: save.roster.activeCompanion, save: &save)
        })
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == 110)
        #expect(reloaded.roster.progression(for: reloaded.roster.activeHero) == beforeHero.addingExperience(4))
        #expect(reloaded.roster.progression(for: reloaded.roster.activeCompanion) == beforeCompanion.addingExperience(5))
    }

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
        let loot = VictoryRewardApplier.resolveLoot(
            .journey(stage: firstStage),
            encounterLevel: encounterLevel,
            enemyIsBoss: false,
            worldSeed: PlayerSave.testWorldSeed,
            ownership: RewardOwnership(ownedTrinketIDs: [], ownedUniqueIDs: []),
        )

        StageCompletion.complete(
            firstStage,
            hero: hero,
            companion: companion,
            battleGold: .init(gained: battleEarnedGold),
            loot: loot,
            in: GameContent.chapters,
            save: &save,
        )

        try #expect(save.roster.gold == loot.gold + battleEarnedGold)
        let heroLevel = PlayerRosterState.testSeed.progression(for: hero).level
        let companionLevel = PlayerRosterState.testSeed.progression(for: companion).level
        let expectedHeroProgression = PlayerRosterState.testSeed.progression(for: hero).addingExperience(
            VictoryRewardApplier.battleExperienceAward(
                playerLevel: heroLevel,
                enemyLevel: encounterLevel,
                highestLevel: PlayerRosterState.testSeed.highestHeroLevel,
            ),
        )
        let expectedCompanionProgression = PlayerRosterState.testSeed.progression(for: companion).addingExperience(
            VictoryRewardApplier.battleExperienceAward(
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
        let loot = VictoryRewardApplier.resolveLoot(
            .journey(stage: firstStage),
            encounterLevel: encounterLevel,
            enemyIsBoss: false,
            worldSeed: PlayerSave.testWorldSeed,
            ownership: RewardOwnership(ownedTrinketIDs: [], ownedUniqueIDs: []),
        )

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            companion: companion,
            battleGold: .init(gained: 0),
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
        let loot = VictoryRewardApplier.resolveLoot(
            .journey(stage: firstStage),
            encounterLevel: EncounterLevelResolver.journeyEnemyLevel(for: firstStage, in: chapter),
            enemyIsBoss: false,
            worldSeed: PlayerSave.testWorldSeed,
            ownership: RewardOwnership(ownedTrinketIDs: [], ownedUniqueIDs: []),
        )

        StageCompletion.complete(
            firstStage,
            hero: hero,
            companion: companion,
            battleGold: .init(gained: 4),
            loot: loot,
            in: GameContent.chapters,
            save: &save,
        )
        let goldAfterFirst = save.roster.gold

        StageCompletion.complete(
            firstStage,
            hero: hero,
            companion: companion,
            battleGold: .init(gained: 2),
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
            id: "test-shop",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            encounter: .shop,
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
            battleGold: .init(gained: 0),
            save: &save,
        )
        let goldAfterClaim = save.roster.gold
        let heroXPAfterClaim = save.roster.progression(for: hero).currentXP
        let itemCountAfterClaim = save.inventory.items.count

        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            companion: companion,
            battleGold: .init(gained: 9),
            save: &save,
        )

        try #expect(save.roster.gold == goldAfterClaim)
        try #expect(save.roster.progression(for: hero).currentXP == heroXPAfterClaim)
        try #expect(save.inventory.items.count == itemCountAfterClaim)
        try #expect(save.journey.hasClaimedRewards(for: firstStage))
    }

    @Test func `resolved gold reward preserves battle spending`() {
        #expect(VictoryRewardApplier.resolvedGoldReward(
            stageGold: 10, battleGold: .init(spent: 20), goldFoundPercent: 50,
        ) == -5)
        #expect(
            VictoryRewardApplier.resolvedGoldReward(
                stageGold: 0,
                battleGold: .init(spent: 3),
                goldFoundPercent: 0,
            ) == -3,
        )
        #expect(
            VictoryRewardApplier.resolvedGoldReward(
                stageGold: 10,
                battleGold: .init(spent: 3),
                goldFoundPercent: 0,
            ) == 7,
        )
    }

    @Test @MainActor func `victory persists gold spent beyond the loot reward`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        try #require(store.persistBatch(logging: "Seed battle wallet") { save in
            save.roster.gold = 100
        })
        try #require(store.persistBatch(logging: "Complete battle with gold spending") { save in
            VictoryRewardApplier.grantVictoryRewards(
                hero: save.roster.activeHero, companion: save.roster.activeCompanion,
                encounterLevel: 1, stageGold: 5, battleGold: .init(spent: 20),
                materialRewards: [], item: nil, save: &save,
            )
        })
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == 85)
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

extension StageRewardTests {
    @Test func `combat loot uses generated gold without authored stacking`() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 0)
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let authored = Stage(
            id: "test-authored",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 98,
            encounter: .battle(enemyID: "test-enemy"),
            rewards: StageReward(gold: 10, itemTemplateIDs: [], materialRewards: []),
        )
        let encounterLevel = EncounterLevelResolver.journeyEnemyLevel(for: firstStage, in: chapter)
        let loot = VictoryRewardApplier.resolveLoot(
            .journey(stage: firstStage),
            encounterLevel: encounterLevel,
            enemyIsBoss: false,
            worldSeed: PlayerSave.testWorldSeed,
            ownership: RewardOwnership(ownedTrinketIDs: [], ownedUniqueIDs: []),
        )

        StageCompletion.claimRewardsIfNeeded(
            for: authored,
            hero: hero,
            companion: companion,
            loot: loot,
            save: &save,
        )

        let expected = VictoryRewardApplier.resolvedGoldReward(
            stageGold: loot.gold,
            battleGold: .init(gained: 0),
            homestead: save.homestead,
        )
        try #expect(save.roster.gold == expected)
    }

    @Test func `negative gold find reduces rewards`() {
        #expect(
            VictoryRewardApplier.resolvedGoldReward(
                stageGold: 10,
                battleGold: .init(gained: 0),
                goldFoundPercent: -50,
            ) < 10,
        )
    }

    @Test func `complete encounter forwards loot to labyrinth`() throws {
        var save = SaveTestSupport.makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        save.labyrinth.ensureMap(
            seed: save.worldSeed,
            eligibleRecruitEventIDs: save.roster.eligibleRecruitEventIDs,
        )
        let node = try #require(save.labyrinth.nodes.values.first { $0.type.isCombat })
        let effects = save.labyrinth.effects(for: node.id)
        let loot = try #require(LabyrinthCompletion.resolveCombatLoot(
            for: node,
            effects: effects,
            worldSeed: save.worldSeed,
            ownedTrinketIDs: [],
            ownedUniqueIDs: [],
        ))

        StageCompletion.completeEncounter(
            stage: firstStage,
            labyrinthNodeID: node.id,
            hero: hero,
            companion: companion,
            loot: loot,
            in: GameContent.chapters,
            save: &save,
        )

        #expect(save.labyrinth.node(id: node.id)?.isCleared == true)
        #expect(save.inventory.item(matching: loot.item.id) != nil)
    }

    @Test func `victory grant is identical across journey dungeon and tower`() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let encounterLevel = EncounterLevelResolver.journeyEnemyLevel(for: firstStage, in: chapter)
        let loot = VictoryRewardApplier.resolveLoot(
            .journey(stage: firstStage),
            encounterLevel: encounterLevel,
            enemyIsBoss: false,
            worldSeed: PlayerSave.testWorldSeed,
            ownership: RewardOwnership(ownedTrinketIDs: [], ownedUniqueIDs: []),
        )
        let materialRewards = [ResourceAmount(.wood, 3), ResourceAmount(.herbs, 2)]

        var journeySave = SaveTestSupport.makeSave()
        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            companion: companion,
            battleGold: .init(gained: 7),
            materialRewards: materialRewards,
            rewardItem: loot.item,
            loot: loot,
            enemyEncounterLevel: encounterLevel,
            save: &journeySave,
        )

        var dungeonSave = SaveTestSupport.makeSave()
        dungeonSave.labyrinth.ensureMap(
            seed: dungeonSave.worldSeed,
            eligibleRecruitEventIDs: dungeonSave.roster.eligibleRecruitEventIDs,
        )
        let node = try #require(dungeonSave.labyrinth.nodes.values.first { $0.type.isCombat })
        LabyrinthCompletion.complete(
            nodeID: node.id,
            hero: hero,
            companion: companion,
            battleGold: .init(gained: 7),
            materialRewards: materialRewards,
            rewardItem: loot.item,
            loot: loot,
            enemyEncounterLevel: encounterLevel,
            save: &dungeonSave,
        )

        var towerSave = SaveTestSupport.makeSave()
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        SpireCompletion.complete(
            floor: floor,
            hero: hero,
            companion: companion,
            battleGold: .init(gained: 7),
            materialRewards: materialRewards,
            rewardItem: loot.item,
            loot: loot,
            enemyEncounterLevel: encounterLevel,
            save: &towerSave,
        )

        try #expect(dungeonSave.roster.gold == journeySave.roster.gold)
        try #expect(towerSave.roster.gold == journeySave.roster.gold)
        try #expect(dungeonSave.homestead.resources == journeySave.homestead.resources)
        try #expect(towerSave.homestead.resources == journeySave.homestead.resources)
    }

    @Test func `near-cap victory converts overflow gold to experience`() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        for gold in [990, 999] {
            var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: gold)
            let heroBefore = save.roster.progression(for: hero)
            VictoryRewardApplier.grantVictoryRewards(
                hero: hero,
                companion: companion,
                encounterLevel: 1,
                stageGold: 20,
                battleGold: .init(),
                materialRewards: [],
                item: nil,
                save: &save,
            )
            #expect(save.roster.gold == gold)
            #expect(save.roster.progression(for: hero).currentXP > heroBefore.currentXP)
        }
    }
}

extension StageRewardTests {
    @Test(arguments: [
        (gold: 979, reserved: 0, spending: 0, converted: false),
        (gold: 980, reserved: 0, spending: 0, converted: true),
        (gold: 970, reserved: 10, spending: 0, converted: true),
        (gold: 990, reserved: 0, spending: 11, converted: false),
        (gold: 999, reserved: 0, spending: 3, converted: true),
    ])
    func `reward settlement conserves spending and replaces only gains that do not fit`(
        scenario: (gold: Int, reserved: Int, spending: Int, converted: Bool),
    ) {
        let plan = BattleRewardPlan(
            stageGold: 20, goldFindPercent: 0, goldOverflowExperience: 7,
            heroExperience: 4, companionExperience: 5, materials: [], items: [],
        )
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: scenario.gold)
        save.homestead.pendingProduction = [.gold: Double(scenario.reserved)]
        let inputs = RewardSettlementInputs(save: save, hero: save.roster.activeHero, companion: save.roster.activeCompanion)
        let settled = plan.settle(battleGold: .init(spent: scenario.spending), inputs: inputs)
        #expect(settled.award.goldGained == (scenario.converted ? 0 : 20))
        #expect(settled.award.goldDelta == (scenario.converted ? 0 : 20) - scenario.spending)
        #expect(settled.replacementExperience == (scenario.converted ? 7 : 0))
        VictoryRewardApplier.apply(settled, hero: save.roster.activeHero, companion: save.roster.activeCompanion, save: &save)
        #expect(save.roster.gold == scenario.gold + settled.award.goldDelta)
        #expect(save.roster.progression(for: save.roster.activeHero) == settled.heroProgressionAfter)
        #expect(save.roster.progression(for: save.roster.activeCompanion) == settled.companionProgressionAfter)
    }
}
