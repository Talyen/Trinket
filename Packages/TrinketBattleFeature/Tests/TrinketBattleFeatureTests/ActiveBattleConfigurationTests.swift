import BattleEngine
import Testing
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence
@testable import TrinketBattleFeature

@MainActor
struct ActiveBattleConfigurationTests {
    @Test func initStoresBakedPresentationFields() throws {
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
        let runKey = BattleRunKey("journey|\(stage.id)")

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            runKey: runKey,
            rngSeed: 0,
            hero: knight,
            companion: wolf,
            enemy: enemy,
            stageReward: loot.asStageReward,
            pendingRewardItem: loot.item,
            stageRewardsAlreadyClaimed: true,
            defeatPrimaryAction: .retreat,
            hasProgressionRewards: true,
            musicStageID: stage.id
        )

        #expect(configuration.runKey == runKey)
        #expect(configuration.musicStageID == stage.id)
        #expect(configuration.hasProgressionRewards)
        #expect(configuration.defeatPrimaryAction == .retreat)
        #expect(configuration.stageRewardsAlreadyClaimed)
        #expect(configuration.stageReward == loot.asStageReward)
        #expect(configuration.rewardItems == [loot.item])
        #expect(configuration.pendingRewardItem == loot.item)
        #expect(configuration.heroExperienceAward >= 0)
        #expect(configuration.companionExperienceAward >= 0)
    }

    @Test func rewardItemsPreferPendingItem() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let pending = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        let runKey = BattleRunKey("journey|test-stage")

        let noItem = try ActiveBattleConfigurationTestSupport.make(
            runKey: runKey,
            rngSeed: 1,
            hero: hero,
            companion: companion,
            enemy: enemy,
            stageReward: StageReward(gold: 10, itemTemplateIDs: []),
            hasProgressionRewards: true
        )
        #expect(noItem.rewardItems.isEmpty)

        let withPending = try ActiveBattleConfigurationTestSupport.make(
            runKey: runKey,
            rngSeed: 1,
            hero: hero,
            companion: companion,
            enemy: enemy,
            stageReward: StageReward(gold: 10, itemTemplateIDs: []),
            pendingRewardItem: pending,
            hasProgressionRewards: true
        )
        #expect(withPending.rewardItems.map(\.id) == [pending.id])
    }

    @Test func initStoresDefeatPrimaryAction() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)

        let restart = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            companion: companion,
            defeatPrimaryAction: .restart
        )
        #expect(restart.defeatPrimaryAction == .restart)

        let retreat = try ActiveBattleConfigurationTestSupport.make(
            runKey: BattleRunKey("labyrinth|node-1"),
            rngSeed: 0,
            hero: hero,
            companion: companion,
            defeatPrimaryAction: .retreat,
            hasProgressionRewards: true
        )
        #expect(retreat.defeatPrimaryAction == .retreat)
    }

    @Test func initPreservesPendingSpireRewardItem() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let pendingItem = try #require(SpireCompletion.resolveLoot(for: floor).item)

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            runKey: BattleRunKey("spire|ironVein|1"),
            rngSeed: 42,
            hero: hero,
            companion: companion,
            enemy: enemy,
            pendingRewardItem: pendingItem,
            hasProgressionRewards: true
        )

        #expect(configuration.pendingRewardItem == pendingItem)
        #expect(configuration.rewardItems == [pendingItem])
    }
}
