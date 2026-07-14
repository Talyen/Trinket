import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

struct BattleVictorySummary: Equatable {
    let stageGold: Int
    let battleGold: Int
    let experience: Int
    let companionExperience: Int
    let heroName: String
    let companionName: String
    let heroArtworkName: String?
    let companionArtworkName: String?
    let rewardItems: [InventoryItem]
    let materialRewards: [ResourceAmount]
    let heroProgressionBefore: CombatantProgression
    let heroProgressionAfter: CombatantProgression
    let companionProgressionBefore: CombatantProgression
    let companionProgressionAfter: CombatantProgression

    var totalGold: Int {
        stageGold + battleGold
    }

    var hasExperienceAwards: Bool {
        experience > 0 || companionExperience > 0
    }

    static func make(
        configuration: ActiveBattleConfiguration,
        state: BattleState,
        homestead: PlayerHomesteadState
    ) -> BattleVictorySummary {
        let stageReward = configuration.stageReward ?? StageReward(gold: 0, itemTemplateIDs: [])
        let enemyLevel = configuration.enemyEncounterLevel ?? configuration.hero.progression.level
        let heroXP = LabyrinthCompletion.adjustedExperienceAward(
            StageCompletion.battleExperienceAward(
                playerLevel: configuration.hero.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: configuration.highestHeroLevel
            ),
            xpPercent: configuration.experienceBonusPercent
        )
        let companionXP = LabyrinthCompletion.adjustedExperienceAward(
            StageCompletion.battleExperienceAward(
                playerLevel: configuration.companion.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: configuration.highestCompanionLevel
            ),
            xpPercent: configuration.experienceBonusPercent
        )
        let heroAfter = configuration.hero.progression.addingExperience(heroXP)
        let companionAfter = configuration.companion.progression.addingExperience(companionXP)
        let materialRewards = StageCompletion.resolvedMaterialRewards(
            stageReward: stageReward
        )
        let totalGold = StageCompletion.resolvedGoldReward(
            stageGold: stageReward.gold,
            battleEarnedGold: state.earnedGold,
            homestead: homestead
        )
        let stageGold = min(stageReward.gold, totalGold)
        let battleGold = max(0, totalGold - stageGold)

        return BattleVictorySummary(
            stageGold: stageGold,
            battleGold: battleGold,
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
