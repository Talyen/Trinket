import Foundation
import TrinketContent
import TrinketCore

public enum StageCompletion {
    public static func battleExperienceAward(
        playerLevel: Int,
        enemyLevel: Int,
        highestLevel: Int,
        experienceEarnedPercent: Int = 0,
    ) -> Int {
        VictoryRewardApplier.battleExperienceAward(
            playerLevel: playerLevel,
            enemyLevel: enemyLevel,
            highestLevel: highestLevel,
            experienceEarnedPercent: experienceEarnedPercent,
        )
    }

    static func adjustedExperienceAward(_ base: Int, experienceEarnedPercent: Int) -> Int {
        CombatRounding.scaled(base, byPercent: experienceEarnedPercent)
    }

    public static func grantBattleExperience(
        enemyLevel: Int,
        to combatant: Combatant,
        roster: inout PlayerRosterState,
        experienceEarnedPercent: Int = 0,
    ) {
        VictoryRewardApplier.grantBattleExperience(
            enemyLevel: enemyLevel,
            to: combatant,
            roster: &roster,
            experienceEarnedPercent: experienceEarnedPercent,
        )
    }

    public static func resolvedMaterialRewards(
        stageReward: StageReward,
        override: [ResourceAmount]? = nil,
    ) -> [ResourceAmount] {
        override ?? stageReward.materialRewards.filter { $0.resource != .gold && $0.quantity > 0 }
    }

    public static func resolveLoot(
        for stage: Stage,
        encounterLevel: Int? = nil,
        enemyIsBoss: Bool? = nil,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        ownedUniqueIDs: Set<String> = [],
        astralChanceBonusPercent: Int = 0,
        in chapters: [Chapter] = GameContent.chapters,
    ) -> BattleLootResult {
        let level = encounterLevel ?? resolvedEncounterLevel(for: stage, in: chapters)
        let isBoss = enemyIsBoss ?? VictoryRewardApplier.isBoss(enemyID: stage.encounter.battleEnemyID)
        return VictoryRewardApplier.resolveLoot(
            .journey(stage: stage),
            encounterLevel: level,
            enemyIsBoss: isBoss,
            worldSeed: worldSeed,
            ownership: RewardOwnership(
                ownedTrinketIDs: ownedTrinketIDs,
                ownedUniqueIDs: ownedUniqueIDs,
            ),
            astralChanceBonusPercent: astralChanceBonusPercent,
        )
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleEarnedGold: Int,
        goldFoundPercent: Int,
    ) -> Int {
        VictoryRewardApplier.resolvedGoldReward(
            stageGold: stageGold,
            battleEarnedGold: battleEarnedGold,
            goldFoundPercent: goldFoundPercent,
        )
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleEarnedGold: Int,
        homestead: PlayerHomesteadState,
    ) -> Int {
        VictoryRewardApplier.resolvedGoldReward(
            stageGold: stageGold,
            battleEarnedGold: battleEarnedGold,
            homestead: homestead,
        )
    }

    public static func resolvedEncounterLevel(for stage: Stage, in chapters: [Chapter]) -> Int {
        guard let chapter = chapters.first(where: { $0.id == stage.chapterID }) else {
            return 1
        }
        return EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
    }

    public static func partyAdjustedEncounterLevel(
        for stage: Stage,
        labyrinthNodeID: String? = nil,
        in chapters: [Chapter] = GameContent.chapters,
        save: PlayerSave,
    ) -> Int {
        let authoredLevel = if let labyrinthNodeID, let node = save.labyrinth.nodes[labyrinthNodeID] {
            EncounterLevelResolver.labyrinthEnemyLevel(for: node)
        } else {
            resolvedEncounterLevel(for: stage, in: chapters)
        }
        return EncounterLevelResolver.partyAdjusted(
            authoredLevel,
            partyAverageLevel: save.roster.activePartyAverageLevel,
        )
    }

    public static func complete(
        _ stage: Stage,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootResult? = nil,
        enemyEncounterLevel: Int? = nil,
        in chapters: [Chapter],
        save: inout PlayerSave,
    ) {
        claimRewardsIfNeeded(
            for: stage,
            hero: hero,
            companion: companion,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards,
            rewardItem: rewardItem,
            loot: loot,
            enemyEncounterLevel: enemyEncounterLevel,
            save: &save,
        )
        if !save.journey.isCompleted(stage) {
            save.journey.complete(stage, in: chapters)
        }
    }

    public static func completeEncounter(
        stage: Stage,
        labyrinthNodeID: String?,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootResult? = nil,
        enemyEncounterLevel: Int? = nil,
        in chapters: [Chapter],
        save: inout PlayerSave,
    ) {
        if let labyrinthNodeID {
            LabyrinthCompletion.complete(
                nodeID: labyrinthNodeID,
                hero: hero,
                companion: companion,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: rewardItem,
                loot: loot,
                enemyEncounterLevel: enemyEncounterLevel,
                save: &save,
            )
            return
        }
        complete(
            stage,
            hero: hero,
            companion: companion,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards,
            rewardItem: rewardItem,
            loot: loot,
            enemyEncounterLevel: enemyEncounterLevel,
            in: chapters,
            save: &save,
        )
    }

    public static func claimRewardsIfNeeded(
        for stage: Stage,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootResult? = nil,
        enemyEncounterLevel: Int? = nil,
        save: inout PlayerSave,
    ) {
        guard !save.journey.hasClaimedRewards(for: stage) else {
            return
        }

        let encounterLevel = enemyEncounterLevel
            ?? partyAdjustedEncounterLevel(for: stage, save: save)
        let enemyIsBoss = VictoryRewardApplier.isBoss(enemyID: stage.encounter.battleEnemyID)

        let resolvedLoot: BattleLootResult? = {
            if let loot {
                return loot
            }
            guard stage.encounter.isCombat else {
                return nil
            }
            return resolveLoot(
                for: stage,
                encounterLevel: encounterLevel,
                enemyIsBoss: enemyIsBoss,
                worldSeed: save.worldSeed,
                ownedTrinketIDs: save.inventory.ownedTrinketIDs,
                ownedUniqueIDs: save.inventory.ownedUniqueIDs,
                astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
            )
        }()

        let stageGold = resolvedLoot?.gold ?? stage.rewards.gold
        let item = VictoryRewardApplier.grantedItem(override: rewardItem, loot: resolvedLoot)
        VictoryRewardApplier.grantVictoryRewards(
            hero: hero,
            companion: companion,
            encounterLevel: encounterLevel,
            stageGold: stageGold,
            battleEarnedGold: battleEarnedGold,
            grantsCombatExperience: stage.encounter.isCombat,
            materialRewards: VictoryRewardApplier.grantedMaterials(
                override: materialRewards,
                loot: resolvedLoot,
                fallback: resolvedMaterialRewards(stageReward: stage.rewards),
            ),
            item: item,
            save: &save,
        )
        if item == nil {
            grantAuthoredItems(for: stage, worldSeed: save.worldSeed, inventory: &save.inventory)
        }

        save.journey.markRewardsClaimed(for: stage)
    }

    private static func grantAuthoredItems(
        for stage: Stage,
        worldSeed: UInt64,
        inventory: inout PlayerInventoryState,
    ) {
        var reservedTrinketIDs = Set<String>()
        for templateID in stage.rewards.itemTemplateIDs {
            guard let template = GameContent.itemTemplate(matching: templateID) else { continue }
            if template.rarity == .astral {
                var randomNumberGenerator = SeededRandomNumberGenerator(
                    seed: GameContent.encounterSeed(
                        worldSeed,
                        salt: "authored-stage-item-\(stage.id)-\(templateID)",
                    ),
                )
                let eligibleTrinkets = GameContent.trinketItems.filter {
                    !inventory.ownedTrinketIDs.contains($0.templateID)
                        && !reservedTrinketIDs.contains($0.templateID)
                }
                if !eligibleTrinkets.isEmpty,
                   Bool.random(using: &randomNumberGenerator),
                   let trinket = eligibleTrinkets.randomElement(using: &randomNumberGenerator) {
                    inventory.appendUniqueItem(trinket)
                    reservedTrinketIDs.insert(trinket.templateID)
                    continue
                }
            }
            inventory.addRewardItem(from: template, for: stage)
        }
    }
}
