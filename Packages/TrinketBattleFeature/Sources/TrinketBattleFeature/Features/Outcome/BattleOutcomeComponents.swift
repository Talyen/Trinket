import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

/// Shared hero/companion experience-award construction for the victory and
/// defeat reveals. Produces both party member awards; VictoryView gates
/// presentation on hasExperienceAwards, while DefeatView retains both rows.
struct BattleExperienceAwardInput {
    let id: String
    let combatantName: String
    let artworkName: String?
    let progressionBefore: CombatantProgression
    let progressionAfter: CombatantProgression
    let experienceAward: Int
}

func battleExperienceAwards(
    hero: BattleExperienceAwardInput,
    companion: BattleExperienceAwardInput,
) -> [RewardRevealExperienceAward] {
    [hero, companion].map { input in
        .init(
            id: input.id,
            combatantName: input.combatantName,
            artworkName: input.artworkName,
            progressionBefore: input.progressionBefore,
            progressionAfter: input.progressionAfter,
            experienceAward: input.experienceAward,
            accessibilityIdentifier: "\(input.combatantName) experience bar",
        )
    }
}

struct BattleOutcomeRewardRow: View {
    let icon: GameIcon
    let tint: Color
    let text: String

    var body: some View {
        Label {
            Text(balanced: text)
                .trinketTypography(.secondaryBody)
        } icon: {
            GameIconImage(icon)
                .foregroundStyle(tint)
        }
    }
}
