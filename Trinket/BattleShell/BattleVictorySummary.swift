import BattleEngine
import Foundation
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
        let enemyLevel = configuration.enemyEncounterLevel ?? configuration.heroProgression.level
        let heroXP = ExperienceScaling.battleAwardWithCatchUp(
            playerLevel: configuration.heroProgression.level,
            enemyLevel: enemyLevel,
            highestLevel: configuration.highestHeroLevel
        )
        let petXP = ExperienceScaling.battleAwardWithCatchUp(
            playerLevel: configuration.petProgression.level,
            enemyLevel: enemyLevel,
            highestLevel: configuration.highestPetLevel
        )
        let heroAfter = configuration.heroProgression.addingExperience(heroXP)
        let petAfter = configuration.petProgression.addingExperience(petXP)
        let materialRewards = homestead.adjustedMaterialRewards(
            configuration.stageReward?.materialRewards ?? []
        )

        return BattleVictorySummary(
            stageGold: configuration.stageReward?.gold ?? 0,
            battleGold: state.earnedGold,
            experience: heroXP,
            petExperience: petXP,
            heroName: state.hero.name,
            petName: state.pet.name,
            itemNames: configuration.rewardItemNames,
            materialRewards: materialRewards,
            heroProgressionBefore: configuration.heroProgression,
            heroProgressionAfter: heroAfter,
            petProgressionBefore: configuration.petProgression,
            petProgressionAfter: petAfter
        )
    }
}
