import BattleEngine
import TrinketContent
import TrinketCore

public struct BattleVictorySummary: Equatable {
    public let settlement: BattleRewardSettlement
    public let heroName: String
    public let companionName: String
    public let heroArtworkName: String?
    public let companionArtworkName: String?

    public var stageGold: Int {
        settlement.award.stageGold
    }

    public var battleGold: Int {
        settlement.award.battleGold
    }

    public var goldFlow: BattleGoldFlow {
        settlement.award.goldFlow
    }

    public var experience: Int {
        settlement.award.heroExperience
    }

    public var companionExperience: Int {
        settlement.award.companionExperience
    }

    public var rewardItems: [InventoryItem] {
        settlement.award.items
    }

    public var materialRewards: [ResourceAmount] {
        settlement.award.materials
    }

    public var heroProgressionBefore: CombatantProgression {
        settlement.inputs.heroProgression
    }

    public var heroProgressionAfter: CombatantProgression {
        settlement.heroProgressionAfter
    }

    public var companionProgressionBefore: CombatantProgression {
        settlement.inputs.companionProgression
    }

    public var companionProgressionAfter: CombatantProgression {
        settlement.companionProgressionAfter
    }

    public var totalGold: Int {
        settlement.award.goldDelta
    }

    public var hasExperienceAwards: Bool {
        experience > 0 || companionExperience > 0
    }

    static func make(
        configuration: BattleRunConfiguration,
        settlement: BattleRewardSettlement,
        heroName: String,
        companionName: String,
    ) -> Self {
        Self(
            settlement: settlement,
            heroName: heroName,
            companionName: companionName,
            heroArtworkName: configuration.hero.combatant.artReference?.thumbnailImageName,
            companionArtworkName: configuration.companion.combatant.artReference?.thumbnailImageName,
        )
    }
}
