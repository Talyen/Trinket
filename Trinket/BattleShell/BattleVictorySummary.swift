import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

struct BattleVictorySummary: Equatable {
    let stageGold: Int
    let battleGold: Int
    let experience: Int
    let petExperience: Int
    let heroName: String
    let petName: String
    let itemNames: [String]
    let materialRewards: [ResourceAmount]
    let heroProgressionBefore: CombatantProgression
    let heroProgressionAfter: CombatantProgression
    let petProgressionBefore: CombatantProgression
    let petProgressionAfter: CombatantProgression

    var totalGold: Int {
        stageGold + battleGold
    }

    var hasExperienceAwards: Bool {
        experience > 0 || petExperience > 0
    }

    static func make(
        configuration: ActiveBattleConfiguration,
        state: BattleState,
        homestead: PlayerHomesteadState
    ) -> BattleVictorySummary {
        let stageReward = configuration.stageReward ?? StageReward(gold: 0, itemTemplateIDs: [])
        let enemyLevel = configuration.enemyEncounterLevel ?? configuration.hero.progression.level
        let heroXP = StageCompletion.battleExperienceAward(
            playerLevel: configuration.hero.progression.level,
            enemyLevel: enemyLevel,
            highestLevel: configuration.highestHeroLevel
        )
        let petXP = StageCompletion.battleExperienceAward(
            playerLevel: configuration.pet.progression.level,
            enemyLevel: enemyLevel,
            highestLevel: configuration.highestPetLevel
        )
        let heroAfter = configuration.hero.progression.addingExperience(heroXP)
        let petAfter = configuration.pet.progression.addingExperience(petXP)
        let materialRewards = StageCompletion.resolvedMaterialRewards(
            stageReward: stageReward,
            homestead: homestead
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
            petExperience: petXP,
            heroName: state.hero.name,
            petName: state.pet.name,
            itemNames: configuration.rewardItemNames,
            materialRewards: materialRewards,
            heroProgressionBefore: configuration.hero.progression,
            heroProgressionAfter: heroAfter,
            petProgressionBefore: configuration.pet.progression,
            petProgressionAfter: petAfter
        )
    }
}
