import TrinketCore

public extension BattleRewardPlan {
    /// Builds launch and unsettled encounter rewards from value inputs only.
    /// Callers own loot selection and claim identity; Content owns reward math.
    static func forEncounter(
        party: (hero: CombatantProgression, companion: CombatantProgression),
        highestLevels: (hero: Int, companion: Int),
        encounterLevel: Int,
        homestead: PlayerHomesteadState,
        stageGold: Int,
        materials: [ResourceAmount],
        items: [InventoryItem],
        experienceEarnedPercent: Int = 0,
        victoryOnlyExperienceBonusPercent: Int = 0,
        grantsCombatExperience: Bool = true,
        rewardsAlreadyClaimed: Bool = false,
        flatExperienceBonus: Int = 0,
        completionBonus: VoyageCompletionBonus? = nil,
    ) -> Self {
        let effects = homestead.effects
        let victoryPercent = SaturatedArithmetic.saturatingAdd(experienceEarnedPercent, victoryOnlyExperienceBonusPercent)
        func experience(for progression: CombatantProgression, highestLevel: Int, percent: Int) -> Int {
            guard grantsCombatExperience, !rewardsAlreadyClaimed else { return 0 }
            return SaturatedArithmetic.saturatingAdd(
                RewardExperiencePolicy.battleExperienceAward(
                    playerLevel: progression.level, enemyLevel: encounterLevel, highestLevel: highestLevel,
                    experienceEarnedPercent: SaturatedArithmetic.saturatingAdd(percent, effects.experienceBonusPercent),
                ),
                flatExperienceBonus,
            )
        }
        return Self(
            stageGold: rewardsAlreadyClaimed ? 0 : stageGold,
            goldFindPercent: effects.goldFindPercent,
            goldFindFlat: effects.goldFindFlat,
            gemsFindBonus: effects.gemsFindBonus,
            gemsFindPercent: effects.gemsFindPercent,
            initialRewardRemainders: homestead.rewardRemainders ?? .zero,
            goldOverflowExperience: RewardExperiencePolicy.encounterAward(
                encounterLevel: encounterLevel, hero: party.hero, companion: party.companion, percent: victoryPercent,
            ),
            heroExperience: experience(for: party.hero, highestLevel: highestLevels.hero, percent: victoryPercent),
            companionExperience: experience(for: party.companion, highestLevel: highestLevels.companion, percent: victoryPercent),
            defeatHeroExperience: experience(for: party.hero, highestLevel: highestLevels.hero, percent: experienceEarnedPercent),
            defeatCompanionExperience: experience(
                for: party.companion,
                highestLevel: highestLevels.companion,
                percent: experienceEarnedPercent,
            ),
            materials: rewardsAlreadyClaimed ? [] : materials,
            items: rewardsAlreadyClaimed ? [] : items,
            completionBonus: rewardsAlreadyClaimed ? nil : completionBonus,
        )
    }
}
