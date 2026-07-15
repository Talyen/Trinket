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
        in chapters: [Chapter],
        save: inout PlayerSave,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
    ) {
        claimRewardsIfNeeded(
            for: stage,
            hero: hero,
            companion: companion,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards,
            enemyEncounterLevel: resolvedEncounterLevel(for: stage, in: chapters),
            save: &save,
            resolveTemplate: resolveTemplate
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
        enemyEncounterLevel: Int? = nil,
        save: inout PlayerSave,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
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

        save.roster.grantGold(
            resolvedGoldReward(
                stageGold: stage.rewards.gold,
                battleEarnedGold: battleEarnedGold,
                homestead: save.homestead
            )
        )
        if case .battle = stage.encounter {
            grantBattleExperience(enemyLevel: encounterLevel, to: hero, roster: &save.roster)
            grantBattleExperience(enemyLevel: encounterLevel, to: companion, roster: &save.roster)
        }
        let resolvedMaterialRewards = resolvedMaterialRewards(
            stageReward: stage.rewards,
            override: materialRewards
        )
        save.homestead.grant(resolvedMaterialRewards)

        for templateID in stage.rewards.itemTemplateIDs {
            guard let template = resolveTemplate(templateID) else { continue }
            save.inventory.addRewardItem(from: template, for: stage)
        }

        save.journey.markRewardsClaimed(for: stage)
    }

    /// Whether `save` already reflects the rewards that `baseline` would gain from `stage`.
    public static func rewardsReflected(
        for stage: Stage,
        baseline: PlayerSave,
        in save: PlayerSave,
        hero: Combatant,
        companion: Combatant,
        in chapters: [Chapter] = GameContent.chapters
    ) -> Bool {
        for templateID in stage.rewards.itemTemplateIDs {
            let itemID = "\(stage.id)-\(templateID)"
            if save.inventory.item(matching: itemID) == nil {
                return false
            }
        }

        let expectedMinGold = baseline.roster.gold + stage.rewards.gold
        if save.roster.gold < expectedMinGold {
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

        guard case .battle = stage.encounter else { return true }

        let encounterLevel = resolvedEncounterLevel(for: stage, in: chapters)
        let heroAward = battleExperienceAward(
            playerLevel: baseline.roster.progression(for: hero).level,
            enemyLevel: encounterLevel,
            highestLevel: baseline.roster.highestHeroLevel
        )
        if !experienceAwardReflected(
            baseline: baseline.roster.progression(for: hero),
            current: save.roster.progression(for: hero),
            award: heroAward
        ) {
            return false
        }

        let companionAward = battleExperienceAward(
            playerLevel: baseline.roster.progression(for: companion).level,
            enemyLevel: encounterLevel,
            highestLevel: baseline.roster.highestCompanionLevel
        )
        return experienceAwardReflected(
            baseline: baseline.roster.progression(for: companion),
            current: save.roster.progression(for: companion),
            award: companionAward
        )
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
