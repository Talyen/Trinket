import BattleEngine
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketBattleFeature

@MainActor
struct ActiveBattleConfigurationTests {
    @Test func storesLaunchBakedDTOValues() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let rewardItem = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
            .rewardInstance(for: "audit-stage")
        let heroProgression = CombatantProgression(level: 4, currentXP: 12, requiredXP: 275)
        let companionProgression = CombatantProgression(level: 2, currentXP: 3, requiredXP: 155)
        let heroModifiers = CombatModifierProfile(maximumHealthBonus: 5)
        let companionModifiers = CombatModifierProfile(damageDealtBonus: [.physical: 2])
        let stageReward = StageReward(
            gold: 18,
            itemTemplateIDs: [],
            materialRewards: [ResourceAmount(.wood, 4)]
        )
        let runKey = BattleRunKey("journey|audit-stage")

        let configuration = ActiveBattleConfigurationTestSupport.make(
            runKey: runKey,
            rngSeed: 42,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 6,
            heroProgression: heroProgression,
            companionProgression: companionProgression,
            heroEquipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.weapon: "shortsword-basic"]),
            companionEquipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.armor: "leather_armor-basic"]),
            heroModifiers: heroModifiers,
            companionModifiers: companionModifiers,
            highestHeroLevel: 9,
            highestCompanionLevel: 7,
            enemyModifiers: CombatModifierProfile(maximumHealthBonus: 3),
            inventoryItems: [rewardItem],
            stageReward: stageReward,
            rewardItems: [rewardItem],
            pendingRewardItem: rewardItem,
            experienceBonusPercent: 20,
            goldFindPercent: 15,
            stageRewardsAlreadyClaimed: true,
            universalModifiers: [.strength(1)],
            defeatPrimaryAction: .retreat,
            hasProgressionRewards: true,
            musicStageID: "audit-stage",
            heroExperienceAward: 31,
            companionExperienceAward: 17,
            materialRewards: [ResourceAmount(.stone, 2)]
        )

        #expect(configuration.runKey == runKey)
        #expect(configuration.rngSeed == 42)
        #expect(configuration.hero.combatant == hero)
        #expect(configuration.hero.progression == heroProgression)
        #expect(configuration.hero.equipmentLoadout.itemID(for: .weapon) == "shortsword-basic")
        #expect(configuration.hero.modifiers == heroModifiers)
        #expect(configuration.companion.progression == companionProgression)
        #expect(configuration.companion.modifiers == companionModifiers)
        #expect(configuration.enemy == enemy)
        #expect(configuration.enemyEncounterLevel == 6)
        #expect(configuration.highestHeroLevel == 9)
        #expect(configuration.highestCompanionLevel == 7)
        #expect(configuration.enemyModifiers.maximumHealthBonus == 3)
        expectBakedOutcomeFields(configuration, rewardItem: rewardItem, stageReward: stageReward)
    }

    private func expectBakedOutcomeFields(
        _ configuration: ActiveBattleConfiguration,
        rewardItem: InventoryItem,
        stageReward: StageReward
    ) {
        #expect(configuration.inventoryItems == [rewardItem])
        #expect(configuration.stageReward == stageReward)
        #expect(configuration.rewardItems == [rewardItem])
        #expect(configuration.pendingRewardItem == rewardItem)
        #expect(configuration.experienceBonusPercent == 20)
        #expect(configuration.goldFindPercent == 15)
        #expect(configuration.stageRewardsAlreadyClaimed)
        #expect(configuration.universalModifiers == [.strength(1)])
        #expect(configuration.defeatPrimaryAction == .retreat)
        #expect(configuration.hasProgressionRewards)
        #expect(configuration.musicStageID == "audit-stage")
        #expect(configuration.heroExperienceAward == 31)
        #expect(configuration.companionExperienceAward == 17)
        #expect(configuration.materialRewards == [ResourceAmount(.stone, 2)])
    }

    @Test func partyMemberLookupUsesBakedCombatantIDs() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let configuration = ActiveBattleConfigurationTestSupport.make(
            hero: hero,
            companion: companion
        )

        #expect(configuration.partyMember(for: hero.id)?.combatant == hero)
        #expect(configuration.partyMember(for: companion.id)?.combatant == companion)
        #expect(configuration.partyMember(for: "unknown") == nil)
    }
}
