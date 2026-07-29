import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

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

    public static func make(
        configuration: ActiveBattleConfiguration,
        state: BattleState
    ) -> Self {
        let stageReward = configuration.stageReward ?? StageReward(gold: 0, itemTemplateIDs: [])
        let enemyLevel = configuration.enemyEncounterLevel ?? configuration.hero.progression.level
        let heroXP = StageCompletion.battleExperienceAward(
            playerLevel: configuration.hero.progression.level,
            enemyLevel: enemyLevel,
            highestLevel: configuration.highestHeroLevel,
            xpPercent: configuration.experienceBonusPercent
        )
        let companionXP = StageCompletion.battleExperienceAward(
            playerLevel: configuration.companion.progression.level,
            enemyLevel: enemyLevel,
            highestLevel: configuration.highestCompanionLevel,
            xpPercent: configuration.experienceBonusPercent
        )
        let heroAfter = configuration.hero.progression.addingExperience(heroXP)
        let companionAfter = configuration.companion.progression.addingExperience(companionXP)
        let materialRewards = StageCompletion.resolvedMaterialRewards(
            stageReward: stageReward
        )
        let rawBattleEarnedGold = state.earnedGold
        let totalGold = StageCompletion.resolvedGoldReward(
            stageGold: stageReward.gold,
            battleEarnedGold: rawBattleEarnedGold,
            goldFindPercent: configuration.goldFindPercent
        )
        let stageGold = min(stageReward.gold, totalGold)
        let battleGold = max(0, totalGold - stageGold)

        return Self(
            stageGold: stageGold,
            battleGold: battleGold,
            rawBattleEarnedGold: rawBattleEarnedGold,
            experience: heroXP,
            companionExperience: companionXP,
            heroName: state.hero.name,
            companionName: state.companion.name,
            heroArtworkName: configuration.hero.combatant.artReference?.thumbnailImageName,
            companionArtworkName: configuration.companion.combatant.artReference?.thumbnailImageName,
            rewardItems: configuration.rewardItems,
            materialRewards: materialRewards,
            heroProgressionBefore: configuration.hero.progression,
            heroProgressionAfter: heroAfter,
            companionProgressionBefore: configuration.companion.progression,
            companionProgressionAfter: companionAfter
        )
    }
}
