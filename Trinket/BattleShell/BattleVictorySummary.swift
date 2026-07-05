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
        let enemyLevel = configuration.enemyEncounterLevel ?? configuration.heroProgression.level
        let heroXP = StageCompletion.battleExperienceAward(
            playerLevel: configuration.heroProgression.level,
            enemyLevel: enemyLevel,
            highestLevel: configuration.highestHeroLevel
        )
        let petXP = StageCompletion.battleExperienceAward(
            playerLevel: configuration.petProgression.level,
            enemyLevel: enemyLevel,
            highestLevel: configuration.highestPetLevel
        )
        let heroAfter = configuration.heroProgression.addingExperience(heroXP)
        let petAfter = configuration.petProgression.addingExperience(petXP)
        let materialRewards = StageCompletion.resolvedMaterialRewards(
            stageReward: stageReward,
            homestead: homestead
        )

        return BattleVictorySummary(
            stageGold: stageReward.gold,
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
