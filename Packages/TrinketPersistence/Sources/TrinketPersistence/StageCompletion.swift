import Foundation
import TrinketContent
import TrinketCore

public enum StageCompletion {
    public static func battleExperienceAward(
        playerLevel: Int,
        enemyLevel: Int,
        highestLevel: Int
    ) -> Int {
        ExperienceScaling.battleAwardWithCatchUp(
            playerLevel: playerLevel,
            enemyLevel: enemyLevel,
            highestLevel: highestLevel
        )
    }

    public static func resolvedMaterialRewards(
        stageReward: StageReward,
        homestead: PlayerHomesteadState,
        override: [ResourceAmount]? = nil
    ) -> [ResourceAmount] {
        override ?? homestead.adjustedMaterialRewards(stageReward.materialRewards)
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
        pet: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        in chapters: [Chapter],
        save: inout PlayerSave,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
    ) {
        claimRewardsIfNeeded(
            for: stage,
            hero: hero,
            pet: pet,
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
        pet: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        enemyEncounterLevel: Int? = nil,
        save: inout PlayerSave,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
    ) {
        guard !save.journey.hasClaimedRewards(for: stage) else {
            return
        }

        let encounterLevel = enemyEncounterLevel
            ?? resolvedEncounterLevel(for: stage, in: GameContent.chapters)

        save.roster.grantGold(stage.rewards.gold + battleEarnedGold)
        if case .battle = stage.encounter {
            grantBattleExperience(enemyLevel: encounterLevel, to: hero, roster: &save.roster)
            grantBattleExperience(enemyLevel: encounterLevel, to: pet, roster: &save.roster)
        }
        let resolvedMaterialRewards = resolvedMaterialRewards(
            stageReward: stage.rewards,
            homestead: save.homestead,
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
        pet: Combatant,
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

        for reward in save.homestead.adjustedMaterialRewards(stage.rewards.materialRewards) {
            let baselineQuantity = baseline.homestead.resources[reward.resource, default: 0]
            if save.homestead.resources[reward.resource, default: 0] < baselineQuantity + reward.quantity {
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

        let petAward = battleExperienceAward(
            playerLevel: baseline.roster.progression(for: pet).level,
            enemyLevel: encounterLevel,
            highestLevel: baseline.roster.highestPetLevel
        )
        return experienceAwardReflected(
            baseline: baseline.roster.progression(for: pet),
            current: save.roster.progression(for: pet),
            award: petAward
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

    private static func grantBattleExperience(
        enemyLevel: Int,
        to combatant: Combatant,
        roster: inout PlayerRosterState
    ) {
        let playerLevel = roster.progression(for: combatant).level
        let highestLevel = combatant.role == .hero
            ? roster.highestHeroLevel
            : roster.highestPetLevel
        let award = battleExperienceAward(
            playerLevel: playerLevel,
            enemyLevel: enemyLevel,
            highestLevel: highestLevel
        )
        roster.grantExperience(award, to: combatant)
    }
}
