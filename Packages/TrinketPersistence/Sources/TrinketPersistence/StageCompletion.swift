import Foundation
import TrinketContent
import TrinketCore

public enum StageCompletion {
    public static func battleExperienceAward(
        playerLevel: Int,
        enemyLevel: Int,
        highestLevel: Int,
        xpPercent: Int = 0
    ) -> Int {
        let raw = adjustedExperienceAward(
            ExperienceScaling.battleAwardWithCatchUp(
                playerLevel: playerLevel,
                enemyLevel: enemyLevel,
                highestLevel: highestLevel
            ),
            xpPercent: xpPercent
        )
        return ExperienceScaling.cappedAward(
            raw,
            requiredXP: CombatantProgression.requiredXP(forLevel: playerLevel)
        )
    }

    /// Applies an optional XP percent bonus (Labyrinth modifiers) to a base award.
    public static func adjustedExperienceAward(_ base: Int, xpPercent: Int) -> Int {
        guard base > 0, xpPercent != 0 else { return max(0, base) }
        return max(0, base + (base * xpPercent) / 100)
    }

    /// Resolves catch-up XP for `combatant` and grants it on `roster`.
    public static func grantBattleExperience(
        enemyLevel: Int,
        to combatant: Combatant,
        roster: inout PlayerRosterState,
        xpPercent: Int = 0
    ) {
        let playerLevel = roster.progression(for: combatant).level
        let highestLevel = combatant.role == .hero
            ? roster.highestHeroLevel
            : roster.highestCompanionLevel
        let award = battleExperienceAward(
            playerLevel: playerLevel,
            enemyLevel: enemyLevel,
            highestLevel: highestLevel,
            xpPercent: xpPercent
        )
        roster.grantExperience(award, to: combatant)
    }

    public static func resolvedMaterialRewards(
        stageReward: StageReward,
        override: [ResourceAmount]? = nil
    ) -> [ResourceAmount] {
        override ?? stageReward.materialRewards.filter { $0.resource != .gold && $0.quantity > 0 }
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleEarnedGold: Int,
        goldFindPercent: Int
    ) -> Int {
        let effects = HomesteadEffects(
            heroModifiers: [],
            companionModifiers: [],
            astralChanceBonusPercent: 0,
            goldFindPercent: goldFindPercent
        )
        return max(
            0,
            effects.adjustedGold(stageGold + max(0, battleEarnedGold))
                + min(0, battleEarnedGold)
        )
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleEarnedGold: Int,
        homestead: PlayerHomesteadState
    ) -> Int {
        resolvedGoldReward(
            stageGold: stageGold,
            battleEarnedGold: battleEarnedGold,
            goldFindPercent: homestead.effects.goldFindPercent
        )
    }

    public static func resolvedEncounterLevel(for stage: Stage, in chapters: [Chapter]) -> Int {
        guard let chapter = chapters.first(where: { $0.id == stage.chapterID }) else {
            return 1
        }
        return EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
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
        save: inout PlayerSave
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
            save: &save
        )
        if !save.journey.isCompleted(stage) {
            save.journey.complete(stage, in: chapters)
        }
    }

    /// Completes a journey stage or Labyrinth node inside an open save mutation.
    public static func completeEncounter(
        stage: Stage,
        labyrinthNodeID: String?,
        hero: Combatant,
        companion: Combatant,
        in chapters: [Chapter],
        save: inout PlayerSave
    ) {
        if let labyrinthNodeID {
            LabyrinthCompletion.complete(
                nodeID: labyrinthNodeID,
                hero: hero,
                companion: companion,
                save: &save
            )
            return
        }
        complete(
            stage,
            hero: hero,
            companion: companion,
            in: chapters,
            save: &save
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
        save: inout PlayerSave
    ) {
        // Stage rewards claim once. Mid-battle gold still banks on claimed-stage
        // replays / auto-complete so resourceGain loot is not silently dropped.
        guard !save.journey.hasClaimedRewards(for: stage) else {
            if battleEarnedGold != 0 {
                save.applyGoldDelta(
                    resolvedGoldReward(
                        stageGold: 0,
                        battleEarnedGold: battleEarnedGold,
                        homestead: save.homestead
                    )
                )
            }
            return
        }

        let encounterLevel = enemyEncounterLevel
            ?? resolvedEncounterLevel(for: stage, in: GameContent.chapters)
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
                astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent
            )
        }()

        let stageGold = resolvedLoot?.gold ?? stage.rewards.gold
        save.applyGoldDelta(
            resolvedGoldReward(
                stageGold: stageGold,
                battleEarnedGold: battleEarnedGold,
                homestead: save.homestead
            )
        )
        if stage.encounter.isCombat {
            grantBattleExperience(enemyLevel: encounterLevel, to: hero, roster: &save.roster)
            grantBattleExperience(enemyLevel: encounterLevel, to: companion, roster: &save.roster)
        }

        let resolvedMaterials = materialRewards
            ?? resolvedLoot?.materials
            ?? resolvedMaterialRewards(stageReward: stage.rewards)
        save.grantMaterials(resolvedMaterials)

        if let rewardItem {
            save.inventory.appendUniqueItem(rewardItem)
        } else if let resolvedLoot {
            save.inventory.appendUniqueItem(resolvedLoot.item)
        } else {
            grantAuthoredItems(for: stage, worldSeed: save.worldSeed, inventory: &save.inventory)
        }

        save.journey.markRewardsClaimed(for: stage)
    }

    private static func grantAuthoredItems(
        for stage: Stage,
        worldSeed: UInt64,
        inventory: inout PlayerInventoryState
    ) {
        for templateID in stage.rewards.itemTemplateIDs {
            guard let template = GameContent.itemTemplate(matching: templateID) else { continue }
            if template.rarity == .astral {
                var randomNumberGenerator = SeededRandomNumberGenerator(
                    seed: GameContent.encounterSeed(
                        worldSeed,
                        salt: "authored-stage-item-\(stage.id)-\(templateID)"
                    )
                )
                let eligibleTrinkets = GameContent.trinketItems.filter {
                    !inventory.ownedTrinketIDs.contains($0.templateID)
                }
                if !eligibleTrinkets.isEmpty,
                   Bool.random(using: &randomNumberGenerator),
                   let trinket = eligibleTrinkets.randomElement(using: &randomNumberGenerator) {
                    inventory.appendUniqueItem(trinket)
                    continue
                }
            }
            inventory.addRewardItem(from: template, for: stage)
        }
    }
}
