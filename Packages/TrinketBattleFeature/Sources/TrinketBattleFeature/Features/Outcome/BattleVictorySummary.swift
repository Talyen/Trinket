import BattleEngine
import TrinketContent

public struct BattleVictorySummary: Equatable {
    public let settlement: BattleRewardSettlement
    public let heroName: String
    public let companionName: String
    public let heroArtworkName: String?
    public let companionArtworkName: String?

    var hasExperienceAwards: Bool {
        settlement.award.heroExperience > 0 || settlement.award.companionExperience > 0
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
