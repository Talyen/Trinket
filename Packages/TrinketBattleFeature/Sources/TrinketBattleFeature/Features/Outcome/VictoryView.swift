import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct VictoryView: View {
    let summary: BattleVictorySummary
    let primaryActionTitle: String
    let primaryActionAccessibilityIdentifier: String
    let onPrimaryAction: () -> Bool

    var body: some View {
        RewardRevealExperienceScreen(
            eyebrow: nil,
            title: "Victory",
            titleAccessibilityIdentifier: AccessibilityID.Battle.victory,
            hasExperienceAwards: summary.hasExperienceAwards,
            loot: .init(
                items: summary.rewardItems,
                gold: summary.totalGold,
                materials: summary.materialRewards,
                showsIncreasePrefix: true,
                emptyMessage: "No additional rewards.",
                itemAccessibilityID: AccessibilityID.Battle.rewardItem,
                lootAccessibilityIdentifier: AccessibilityID.Battle.rewards
            ),
            primaryActionTitle: primaryActionTitle,
            primaryActionAccessibilityIdentifier: primaryActionAccessibilityIdentifier,
            onPrimaryAction: onPrimaryAction,
            contentTopPadding: TrinketDesign.Metrics.extraSmallSpacing,
            contentStackSpacing: TrinketDesign.Metrics.largeSpacing
        ) { onExperienceBarCompleted in
            experiencePanel(onExperienceBarCompleted: onExperienceBarCompleted)
        }
    }

    @ViewBuilder
    private func experiencePanel(onExperienceBarCompleted: @escaping () -> Void) -> some View {
        if summary.hasExperienceAwards {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
                ExperienceBar(
                    combatantName: summary.heroName,
                    artworkName: summary.heroArtworkName,
                    pre: summary.heroProgressionBefore,
                    post: summary.heroProgressionAfter,
                    fillColor: TrinketDesign.Colors.accentEmphasized,
                    experienceAward: summary.experience,
                    snapToFinal: false,
                    onAnimationCompleted: onExperienceBarCompleted
                )
                .accessibilityIdentifier("\(summary.heroName) experience bar")

                ExperienceBar(
                    combatantName: summary.companionName,
                    artworkName: summary.companionArtworkName,
                    pre: summary.companionProgressionBefore,
                    post: summary.companionProgressionAfter,
                    fillColor: TrinketDesign.Colors.accentEmphasized,
                    experienceAward: summary.companionExperience,
                    snapToFinal: false,
                    onAnimationCompleted: onExperienceBarCompleted
                )
                .accessibilityIdentifier("\(summary.companionName) experience bar")
            }
            .trinketSurface(.secondary)
            .accessibilityIdentifier(AccessibilityID.Battle.experience)
        } else {
            BattleOutcomeRewardRow(
                symbolName: "star",
                tint: .secondary,
                text: "No experience awarded."
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .trinketSurface(.secondary)
            .accessibilityIdentifier(AccessibilityID.Battle.experience)
        }
    }
}
