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
        let itemTemplateID = try #require(stage.rewards.itemTemplateIDs.first)
        let expectedItem = try #require(GameContent.itemTemplate(matching: itemTemplateID))

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .journey(stageID: stage.id),
            rngSeed: 0,
            hero: knight,
            companion: wolf,
            enemy: enemy,
            stageReward: stage.rewards
        )

        #expect(configuration.resumeToken == .journey(stageID: stage.id))
        #expect(configuration.stageID == stage.id)
        #expect(configuration.stageReward == stage.rewards)
        #expect(configuration.rewardItems.map(\.displayName) == [expectedItem.displayName])
        #expect(configuration.rewardItems.first?.id == "\(stage.id)-\(itemTemplateID)")
        #expect(configuration.rewardItems.first?.affixes == expectedItem.affixes)
    }

    @Test func rewardResolutionCoversNoItemAndMultipleJourneyItems() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)

        let noItem = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .journey(stageID: "test-stage"),
            rngSeed: 1,
            hero: hero,
            companion: companion,
            enemy: enemy,
            stageReward: StageReward(gold: 10, itemTemplateIDs: [])
        )
        #expect(noItem.rewardItems.isEmpty)

        let multiple = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .journey(stageID: "test-stage"),
            rngSeed: 1,
            hero: hero,
            companion: companion,
            enemy: enemy,
            stageReward: StageReward(
                gold: 10,
                itemTemplateIDs: ["shortsword-basic", "longsword-basic"]
            )
        )
        #expect(multiple.rewardItems.map(\.id) == [
            "test-stage-shortsword-basic",
            "test-stage-longsword-basic"
        ])
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
        #expect(configuration.rewardItems[0].rarity == pendingItem.rarity)
        #expect(configuration.rewardItems[0].affixes == pendingItem.affixes)
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
