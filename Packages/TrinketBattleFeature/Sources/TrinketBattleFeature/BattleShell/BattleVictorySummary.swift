import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketFeatureSupport

public struct BattleVictorySummary: Equatable {
    public let stageGold: Int
    public let battleGold: Int
    public let goldFlow: BattleGoldFlow
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
        configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext,
        battleGold: BattleGoldFlow,
        heroName: String,
        companionName: String,
    ) -> Self {
        let award = presentation.rewardPlan.resolve(battleGold: battleGold)
        let heroXP = award.heroExperience
        let companionXP = award.companionExperience
        let heroAfter = configuration.hero.progression.addingExperience(heroXP)
        let companionAfter = configuration.companion.progression.addingExperience(companionXP)

        return Self(
            stageGold: award.stageGold,
            battleGold: award.battleGold,
            goldFlow: battleGold,
            experience: heroXP,
            companionExperience: companionXP,
            heroName: heroName,
            companionName: companionName,
            heroArtworkName: configuration.hero.combatant.artReference?.thumbnailImageName,
            companionArtworkName: configuration.companion.combatant.artReference?.thumbnailImageName,
            rewardItems: award.items,
            materialRewards: award.materials,
            heroProgressionBefore: configuration.hero.progression,
            heroProgressionAfter: heroAfter,
            companionProgressionBefore: configuration.companion.progression,
            companionProgressionAfter: companionAfter,
        )
    }
}
