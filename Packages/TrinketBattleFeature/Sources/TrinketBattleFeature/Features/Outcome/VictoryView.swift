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
            experienceAwards: experienceAwards,
            experienceAccessibilityIdentifier: AccessibilityID.Battle.experience,
            loot: .init(
                items: summary.rewardItems,
                gold: summary.totalGold,
                materials: summary.materialRewards,
                showsIncreasePrefix: true,
                emptyMessage: "No additional rewards.",
                itemAccessibilityID: AccessibilityID.Battle.rewardItem,
                lootAccessibilityIdentifier: AccessibilityID.Battle.rewards,
            ),
            primaryActionTitle: primaryActionTitle,
            primaryActionAccessibilityIdentifier: primaryActionAccessibilityIdentifier,
            onPrimaryAction: onPrimaryAction,
            contentTopPadding: TrinketDesign.Metrics.extraSmallSpacing,
            contentStackSpacing: TrinketDesign.Metrics.largeSpacing,
            emptyExperience: {
                BattleOutcomeRewardRow(
                    symbolName: "star",
                    tint: .secondary,
                    text: "No experience awarded.",
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            },
        )
    }

    private var experienceAwards: [RewardRevealExperienceAward] {
        guard summary.hasExperienceAwards else { return [] }
        return [
            .init(
                id: "hero",
                combatantName: summary.heroName,
                artworkName: summary.heroArtworkName,
                progressionBefore: summary.heroProgressionBefore,
                progressionAfter: summary.heroProgressionAfter,
                experienceAward: summary.experience,
                accessibilityIdentifier: "\(summary.heroName) experience bar",
            ),
            .init(
                id: "companion",
                combatantName: summary.companionName,
                artworkName: summary.companionArtworkName,
                progressionBefore: summary.companionProgressionBefore,
                progressionAfter: summary.companionProgressionAfter,
                experienceAward: summary.companionExperience,
                accessibilityIdentifier: "\(summary.companionName) experience bar",
            ),
        ]
    }
}
