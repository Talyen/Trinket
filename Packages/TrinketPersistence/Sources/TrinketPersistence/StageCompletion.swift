import Foundation
import TrinketContent
import TrinketCore

public enum StageCompletion {
    public static func battleExperienceAward(
        playerLevel: Int,
        enemyLevel: Int,
        highestLevel: Int,
        xpPercent: Int = 0,
    ) -> Int {
        let raw = adjustedExperienceAward(
            ExperienceScaling.battleAwardWithCatchUp(
                playerLevel: playerLevel,
                enemyLevel: enemyLevel,
                highestLevel: highestLevel,
            ),
            xpPercent: xpPercent,
        )
        return ExperienceScaling.cappedAward(
            raw,
            requiredXP: CombatantProgression.requiredXP(forLevel: playerLevel),
        )
    }

    static func adjustedExperienceAward(_ base: Int, xpPercent: Int) -> Int {
        CombatRounding.scaled(base, byPercent: xpPercent)
    }

    public static func grantBattleExperience(
        enemyLevel: Int,
        to combatant: Combatant,
        roster: inout PlayerRosterState,
        xpPercent: Int = 0,
    ) {
        let playerLevel = roster.progression(for: combatant).level
        let highestLevel = combatant.role == .hero
            ? roster.highestHeroLevel
            : roster.highestCompanionLevel
        let award = battleExperienceAward(
            playerLevel: playerLevel,
            enemyLevel: enemyLevel,
            highestLevel: highestLevel,
            xpPercent: xpPercent,
        )
        roster.grantExperience(award, to: combatant)
    }

    public static func resolvedMaterialRewards(
        stageReward: StageReward,
        override: [ResourceAmount]? = nil,
    ) -> [ResourceAmount] {
        override ?? stageReward.materialRewards.filter { $0.resource != .gold && $0.quantity > 0 }
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleEarnedGold: Int,
        goldFindPercent: Int,
    ) -> Int {
        let effects = HomesteadEffects(
            heroModifiers: [],
            companionModifiers: [],
            astralChanceBonusPercent: 0,
            goldFindPercent: goldFindPercent,
        )
        return max(
            0,
            effects.adjustedGold(stageGold + max(0, battleEarnedGold))
                + min(0, battleEarnedGold),
        )
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleEarnedGold: Int,
        homestead: PlayerHomesteadState,
    ) -> Int {
        resolvedGoldReward(
            stageGold: stageGold,
            battleEarnedGold: battleEarnedGold,
            goldFindPercent: homestead.effects.goldFindPercent,
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

    static func grantVictoryRewards(
        hero: Combatant,
        companion: Combatant,
        encounterLevel: Int,
        stageGold: Int,
        battleEarnedGold: Int = 0,
        grantsCombatExperience: Bool = true,
        xpPercent: Int = 0,
        materials: [ResourceAmount],
        item: InventoryItem?,
        save: inout PlayerSave,
    ) {
        let now = Date()
        save.applyGoldDelta(
            resolvedGoldReward(
                stageGold: stageGold,
                battleEarnedGold: battleEarnedGold,
                homestead: save.homestead,
            ),
            at: now,
        )
        if grantsCombatExperience {
            grantBattleExperience(enemyLevel: encounterLevel, to: hero, roster: &save.roster, xpPercent: xpPercent)
            grantBattleExperience(enemyLevel: encounterLevel, to: companion, roster: &save.roster, xpPercent: xpPercent)
        }
        save.grantMaterials(materials, at: now)
        if let item {
            save.inventory.appendUniqueItem(item)
        }
    }

    public static func complete(
        _ stage: Stage,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootPackage? = nil,
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
        in chapters: [Chapter],
        save: inout PlayerSave,
    ) {
        if let labyrinthNodeID {
            LabyrinthCompletion.complete(
                nodeID: labyrinthNodeID,
                hero: hero,
                companion: companion,
                save: &save,
            )
            return
        }
        complete(
            stage,
            hero: hero,
            companion: companion,
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
        loot: BattleLootPackage? = nil,
        enemyEncounterLevel: Int? = nil,
        save: inout PlayerSave,
    ) {
        guard !save.journey.hasClaimedRewards(for: stage) else {
            return
        }

        let encounterLevel = enemyEncounterLevel
            ?? partyAdjustedEncounterLevel(for: stage, save: save)
        let enemyIsBoss: Bool = {
            guard let enemyID = stage.encounter.battleEnemyID else { return false }
            return GameContent.enemy(matching: enemyID)?.isBoss == true
        }()

        let resolvedLoot: BattleLootPackage? = {
            if let loot {
                return loot
            }
            guard stage.encounter.isCombat else {
                return nil
            }
            return BattleLoot.resolveJourney(
                stage: stage,
                encounterLevel: encounterLevel,
                enemyIsBoss: enemyIsBoss,
                worldSeed: save.worldSeed,
                ownedTrinketIDs: save.inventory.ownedTrinketIDs,
                ownedUniqueIDs: save.inventory.ownedUniqueIDs,
                astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
            )
        }()

        let stageGold = resolvedLoot?.gold ?? stage.rewards.gold
        let item: InventoryItem? = if let rewardItem {
            rewardItem
        } else if let resolvedLoot {
            resolvedLoot.item
        } else {
            nil
        }
        grantVictoryRewards(
            hero: hero,
            companion: companion,
            encounterLevel: encounterLevel,
            stageGold: stageGold,
            battleEarnedGold: battleEarnedGold,
            grantsCombatExperience: stage.encounter.isCombat,
            materials: materialRewards
                ?? resolvedLoot?.materials
                ?? resolvedMaterialRewards(stageReward: stage.rewards),
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
