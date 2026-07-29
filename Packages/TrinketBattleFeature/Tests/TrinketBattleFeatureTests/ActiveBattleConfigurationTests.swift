import BattleEngine
import Testing
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence
@testable import TrinketBattleFeature

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
        #expect(configuration.enemyModifiers.damageTakenReduction(for: .bleed) > 0)
    }

    @Test func universalDamageModifierAppliesToEveryCombatant() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let modifier = AffixModifier.damageDealt(.burn, 1)

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            universalModifiers: [modifier]
        )

        #expect(configuration.universalModifiers == [modifier])
        #expect(configuration.hero.modifiers.damageDealtBonus(for: .burn) == 1)
        #expect(configuration.companion.modifiers.damageDealtBonus(for: .burn) == 1)
        #expect(configuration.enemyModifiers.damageDealtBonus(for: .burn) == 1)
    }

    @Test func makePreservesStageMetadata() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battleEnemyID = try #require(stage.encounter.battleEnemyID)
        let enemy = try #require(GameContent.enemy(matching: battleEnemyID)?.combatant)
        let loot = try #require(BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: 1,
            enemyIsBoss: false
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

    @Test func makeBakesGoldFindAndClaimedStagePolicy() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battleEnemyID = try #require(stage.encounter.battleEnemyID)
        let enemy = try #require(GameContent.enemy(matching: battleEnemyID)?.combatant)
        let homestead = PlayerHomesteadState(resources: [:], nodeTiers: [.wishingWell: 2])

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .journey(stageID: stage.id),
            rngSeed: 0,
            hero: knight,
            companion: wolf,
            enemy: enemy,
            homestead: homestead,
            stageRewardsAlreadyClaimed: true
        )

        #expect(configuration.goldFindPercent == homestead.effects.goldFindPercent)
        #expect(configuration.goldFindPercent > 0)
        #expect(configuration.stageRewardsAlreadyClaimed)
    }

    @Test func makePreservesPendingSpireRewardItem() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let pendingItem = try #require(SpireCompletion.resolveLoot(for: floor).item)

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .spire(spireID: .ironVein, floor: 1),
            rngSeed: 42,
            hero: hero,
            companion: companion,
            enemy: enemy,
            pendingRewardItem: pendingItem
        )

        #expect(configuration.pendingRewardItem == pendingItem)
        #expect(configuration.rewardItems == [pendingItem])
    }

    @Test func makePreservesPreScaledEnemyStats() throws {
        let chapter = try #require(GameContent.chapters.first)
        let battleStages = chapter.stages.filter(\.encounter.isCombat)
        let stage = try #require(battleStages.last)
        let expectedLevel = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        #expect(expectedLevel > 1)

        let enemyID = try #require(stage.resolvedBattleEnemyID)
        let catalogEnemy = try #require(GameContent.enemy(matching: enemyID))
        let scaledEnemy = CombatantLevelScaler.scale(enemy: catalogEnemy, level: expectedLevel)

        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .journey(stageID: stage.id),
            rngSeed: 0,
            hero: knight,
            companion: wolf,
            enemy: scaledEnemy,
            enemyEncounterLevel: expectedLevel
        )

        let enemy = try #require(configuration.enemy)
        #expect(enemy.maxHealth == scaledEnemy.maxHealth)
        #expect(enemy.maxHealth > catalogEnemy.combatant.maxHealth)
        #expect(configuration.enemyEncounterLevel == expectedLevel)
        #expect(configuration.enemyModifiers.triggers.controlResistancePercent >= 0)
    }
}
