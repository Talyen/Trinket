import Testing
import TrinketContent
import TrinketPersistence
@testable import Trinket

@MainActor
struct ActiveBattleConfigurationTests {
    @Test func makeResolvesEnemyTraitModifiers() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let skeleton = try #require(GameContent.enemy(matching: "skeleton"))

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: knight,
            companion: wolf,
            enemy: skeleton.combatant
        )

        #expect(configuration.enemyModifiers.damageTakenVulnerability(for: .holy) > 0)
        #expect(configuration.enemyModifiers.controlResistancePercent > 0)
    }

    @Test func makePreservesStageMetadata() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battleEnemyID = try #require(stage.encounter.battleEnemyID)
        let enemy = try #require(GameContent.enemy(matching: battleEnemyID)?.combatant)
        let loot = try #require(ActiveBattleConfiguration.lootPackage(
            for: .journey(stageID: stage.id),
            enemy: enemy,
            encounterLevel: 1
        ))

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .journey(stageID: stage.id),
            rngSeed: 0,
            hero: knight,
            companion: wolf,
            enemy: enemy,
            stageReward: loot.asStageReward,
            pendingRewardItem: loot.item
        )

        #expect(configuration.resumeToken == .journey(stageID: stage.id))
        #expect(configuration.stageID == stage.id)
        #expect(configuration.stageReward == loot.asStageReward)
        #expect(configuration.rewardItems == [loot.item])
        #expect(configuration.pendingRewardItem == loot.item)
    }

    @Test func lootPackageMatchesPersistenceResolvers() throws {
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battleEnemyID = try #require(stage.encounter.battleEnemyID)
        let enemy = try #require(GameContent.enemy(matching: battleEnemyID)?.combatant)
        let journeyLoot = try #require(ActiveBattleConfiguration.lootPackage(
            for: .journey(stageID: stage.id),
            enemy: enemy,
            encounterLevel: 1
        ))
        #expect(
            journeyLoot == BattleLoot.resolveJourney(
                stage: stage,
                encounterLevel: 1,
                enemyIsBoss: false
            )
        )

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let aspectLoot = try #require(ActiveBattleConfiguration.lootPackage(
            for: .aspect(aspectID: .ironVein, floor: 1)
        ))
        #expect(aspectLoot == AspectCompletion.resolveLoot(for: floor))

        var labyrinth = PlayerLabyrinthState.freshStart
        labyrinth.ensureMap()
        let maybeCombatNode = labyrinth.nodes.values.first(where: \.type.isCombat)
        let combatNode = try #require(maybeCombatNode)
        let labyrinthLoot = ActiveBattleConfiguration.lootPackage(
            for: .labyrinth(nodeID: combatNode.id),
            labyrinth: labyrinth
        )
        #expect(
            labyrinthLoot == LabyrinthCompletion.resolveCombatLoot(
                for: combatNode,
                effects: labyrinth.effects(for: combatNode.id),
                worldSeed: labyrinth.worldSeed
            )
        )
    }

    @Test func rewardResolutionPrefersPendingItem() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let pending = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))

        let noItem = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .journey(stageID: "test-stage"),
            rngSeed: 1,
            hero: hero,
            companion: companion,
            enemy: enemy,
            stageReward: StageReward(gold: 10, itemTemplateIDs: [])
        )
        #expect(noItem.rewardItems.isEmpty)

        let withPending = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .journey(stageID: "test-stage"),
            rngSeed: 1,
            hero: hero,
            companion: companion,
            enemy: enemy,
            stageReward: StageReward(gold: 10, itemTemplateIDs: []),
            pendingRewardItem: pending
        )
        #expect(withPending.rewardItems.map(\.id) == [pending.id])
    }

    @Test func aspectRewardUsesTheExactGeneratedPersistenceItem() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .aspect(aspectID: .ironVein, floor: 1),
            rngSeed: 42,
            hero: hero,
            companion: companion,
            enemy: enemy
        )
        let pendingItem = try #require(configuration.pendingRewardItem)

        #expect(configuration.rewardItems == [pendingItem])
    }

    @Test func makePreservesJourneyScaledEnemyStats() throws {
        let chapter = try #require(GameContent.chapters.first)
        let battleStages = chapter.stages.filter {
            if case .battle = $0.encounter {
                return true
            }
            return false
        }
        let stage = try #require(battleStages.last)
        let encounter = try #require(ActiveBattleConfiguration.resolvedEncounter(for: stage))
        let expectedLevel = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        #expect(encounter.level == expectedLevel)
        #expect(encounter.level > 1)
        #expect(encounter.combatant.id == stage.encounter.battleEnemyID)

        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let catalogEnemy = try #require(GameContent.enemy(matching: encounter.combatant.id))

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .journey(stageID: stage.id),
            rngSeed: 0,
            hero: knight,
            companion: wolf,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level
        )

        let enemy = try #require(configuration.enemy)
        #expect(enemy.maxHealth == encounter.combatant.maxHealth)
        #expect(enemy.maxHealth > catalogEnemy.combatant.maxHealth)
        #expect(configuration.enemyEncounterLevel == encounter.level)
        #expect(configuration.enemyModifiers.controlResistancePercent >= 0)
    }
}
