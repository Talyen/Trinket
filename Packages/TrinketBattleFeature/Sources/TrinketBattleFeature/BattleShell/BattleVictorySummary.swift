import Foundation
import TrinketBattleContracts
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureSupport

public struct BattleVictorySummary: Equatable {
    public let stageGold: Int
    public let battleGold: Int
    /// Unadjusted mid-battle gold for grant paths. Do not pass `battleGold` into
    /// completion APIs — that display split already includes homestead bonus.
    public let rawBattleEarnedGold: Int
    public let experience: Int
    public let companionExperience: Int
    public let heroName: String
    public let companionName: String
    public let heroArtworkName: String?
    public let companionArtworkName: String?
    public let rewardItems: [InventoryItem]
    public let materialRewards: [ResourceAmount]
    public let heroProgressionBefore: CombatantProgression
    public let heroProgressionAfter: CombatantProgression
    public let companionProgressionBefore: CombatantProgression
    public let companionProgressionAfter: CombatantProgression

    public var totalGold: Int {
        stageGold + battleGold
    }

    public var hasExperienceAwards: Bool {
        experience > 0 || companionExperience > 0
    }

    /// Assembles victory chrome from launch-baked awards plus mid-battle earned gold.
    /// Does not re-derive XP / material Persistence policy.
    public static func make(
        configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext,
        earnedGold: Int,
        heroName: String,
        companionName: String
    ) -> Self {
        let stageReward = presentation.stageReward ?? StageReward(gold: 0, itemTemplateIDs: [])
        let heroXP = presentation.heroExperienceAward
        let companionXP = presentation.companionExperienceAward
        let heroAfter = configuration.hero.progression.addingExperience(heroXP)
        let companionAfter = configuration.companion.progression.addingExperience(companionXP)
        let rawBattleEarnedGold = earnedGold
        let totalGold = HomesteadEffects(
            heroModifiers: [],
            companionModifiers: [],
            astralChanceBonusPercent: 0,
            goldFindPercent: presentation.goldFindPercent
        ).adjustedGold(stageReward.gold + rawBattleEarnedGold)
        let stageGold = min(stageReward.gold, totalGold)
        let battleGold = max(0, totalGold - stageGold)

        return Self(
            stageGold: stageGold,
            battleGold: battleGold,
            rawBattleEarnedGold: rawBattleEarnedGold,
            experience: heroXP,
            companionExperience: companionXP,
            heroName: heroName,
            companionName: companionName,
            heroArtworkName: configuration.hero.combatant.artReference?.thumbnailImageName,
            companionArtworkName: configuration.companion.combatant.artReference?.thumbnailImageName,
            rewardItems: presentation.rewardItems,
            materialRewards: presentation.materialRewards,
            heroProgressionBefore: configuration.hero.progression,
            heroProgressionAfter: heroAfter,
            companionProgressionBefore: configuration.companion.progression,
            companionProgressionAfter: companionAfter
        )
    }
}
