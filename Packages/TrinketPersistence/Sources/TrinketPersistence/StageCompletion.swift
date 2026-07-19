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
        adjustedExperienceAward(
            ExperienceScaling.battleAwardWithCatchUp(
                playerLevel: playerLevel,
                enemyLevel: enemyLevel,
                highestLevel: highestLevel
            ),
            xpPercent: xpPercent
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
        homestead: PlayerHomesteadState
    ) -> Int {
        homestead.effects.adjustedGold(stageGold + battleEarnedGold)
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
            enemyEncounterLevel: resolvedEncounterLevel(for: stage, in: chapters),
            save: &save
        )
        if !save.journey.isCompleted(stage) {
            save.journey.complete(stage, in: chapters)
        }
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
            if battleEarnedGold > 0 {
                save.roster.grantGold(
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
            guard case .battle = stage.encounter else {
                return nil
            }
            return BattleLoot.resolveJourney(
                stage: stage,
                encounterLevel: encounterLevel,
                enemyIsBoss: enemyIsBoss
            )
        }()

        let stageGold = resolvedLoot?.gold ?? stage.rewards.gold
        save.roster.grantGold(
            resolvedGoldReward(
                stageGold: stageGold,
                battleEarnedGold: battleEarnedGold,
                homestead: save.homestead
            )
        )
        if case .battle = stage.encounter {
            grantBattleExperience(enemyLevel: encounterLevel, to: hero, roster: &save.roster)
            grantBattleExperience(enemyLevel: encounterLevel, to: companion, roster: &save.roster)
        }

        let resolvedMaterials = materialRewards
            ?? resolvedLoot?.materials
            ?? resolvedMaterialRewards(stageReward: stage.rewards)
        save.homestead.grant(resolvedMaterials)

        if let rewardItem {
            save.inventory.appendUniqueItem(rewardItem)
        } else if let resolvedLoot {
            save.inventory.appendUniqueItem(resolvedLoot.item)
        } else {
            for templateID in stage.rewards.itemTemplateIDs {
                guard let template = GameContent.itemTemplate(matching: templateID) else { continue }
                save.inventory.addRewardItem(from: template, for: stage)
            }
        }

        save.journey.markRewardsClaimed(for: stage)
    }

    private static func currencyAndItemsReflected(
        for stage: Stage,
        baseline: PlayerSave,
        in save: PlayerSave,
        chapters: [Chapter]
    ) -> Bool {
        if case .battle = stage.encounter {
            let encounterLevel = resolvedEncounterLevel(for: stage, in: chapters)
            let enemyIsBoss = stage.encounter.battleEnemyID
                .flatMap(GameContent.enemy(matching:))?.isBoss == true
            let loot = BattleLoot.resolveJourney(
                stage: stage,
                encounterLevel: encounterLevel,
                enemyIsBoss: enemyIsBoss
            )
            return packageReflected(loot, baseline: baseline, in: save)
        }

        for templateID in stage.rewards.itemTemplateIDs {
            let itemID = "\(stage.id)-\(templateID)"
            if save.inventory.item(matching: itemID) == nil {
                return false
            }
        }
        if save.roster.gold < baseline.roster.gold + stage.rewards.gold {
            return false
        }
        for reward in stage.rewards.materialRewards where reward.resource != .gold && reward.quantity > 0 {
            let baselineQuantity = baseline.homestead.resources[reward.resource, default: 0]
            let expectedQuantity = min(
                baselineQuantity + reward.quantity,
                PlayerHomesteadState.maxMaterialBalance
            )
            if save.homestead.resources[reward.resource, default: 0] < expectedQuantity {
                return false
            }
        }
        return true
    }

    private static func packageReflected(
        _ loot: BattleLootPackage,
        baseline: PlayerSave,
        in save: PlayerSave
    ) -> Bool {
        if save.inventory.item(matching: loot.item.id) == nil {
            return false
        }
        if save.roster.gold < baseline.roster.gold + loot.gold {
            return false
        }
        for reward in loot.materials where reward.quantity > 0 {
            let baselineQuantity = baseline.homestead.resources[reward.resource, default: 0]
            let expectedQuantity = min(
                baselineQuantity + reward.quantity,
                PlayerHomesteadState.maxMaterialBalance
            )
            if save.homestead.resources[reward.resource, default: 0] < expectedQuantity {
                return false
            }
        }
        return true
    }

    private static func experienceAwardReflected(
        baseline: CombatantProgression,
        current: CombatantProgression,
        award: Int
    ) -> Bool {
        if award == 0 {
            return true
        }
        if current.level > baseline.level {
            return true
        }
        if current.level == baseline.level, current.currentXP >= baseline.currentXP + award {
            return true
        }
        return false
    }
}
