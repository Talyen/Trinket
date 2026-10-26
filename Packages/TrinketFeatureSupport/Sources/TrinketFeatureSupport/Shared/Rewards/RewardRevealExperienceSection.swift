import SwiftUI
import TrinketDesignSystem

public struct RewardRevealExperienceSection: View {
    let awards: [RewardRevealExperienceAward]
    let spacing: CGFloat

    public init(
        awards: [RewardRevealExperienceAward],
        spacing: CGFloat = TrinketDesign.Spacing.medium,
    ) {
        self.awards = awards
        self.spacing = spacing
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(awards) { award in
                ExperienceBar(
                    combatantName: award.combatantName,
                    artworkName: award.artworkName,
                    pre: award.progressionBefore,
                    post: award.progressionAfter,
                    fillColor: TrinketDesign.Colors.accentEmphasized,
                    experienceAward: award.experienceAward,
                    snapToFinal: award.experienceAward == 0,
                )
                .accessibilityIdentifier(award.accessibilityIdentifier ?? "\(award.combatantName) experience bar")
            }
        }
        .trinketSurface(.secondary)
    }
}
