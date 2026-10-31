import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct VictoryView: View {
    let summary: BattleVictorySummary
    let primaryActionTitle: String
    let primaryActionAccessibilityIdentifier: String
    let action: RewardRevealAction
    var onExceptionalReveal: () -> Void = {}

    var body: some View {
        RewardRevealExperienceScreen(
            eyebrow: nil,
            title: String(localized: L10n.ui_victoryview_victory_2e9b5),
            titleAccessibilityIdentifier: AccessibilityID.Battle.victory,
            experienceAwards: experienceAwards,
            experienceAccessibilityIdentifier: AccessibilityID.Battle.experience,
            loot: .init(
                items: summary.settlement.award.items,
                gold: summary.settlement.award.goldDelta,
                materials: summary.settlement.award.materials,
                showsIncreasePrefix: true,
                emptyMessage: String(localized: L10n.ui_victoryview_no_additional_rewards_2d56e),
                itemAccessibilityID: AccessibilityID.Battle.rewardItem,
                lootAccessibilityIdentifier: AccessibilityID.Battle.rewards,
            ),
            primaryActionTitle: primaryActionTitle,
            primaryActionAccessibilityIdentifier: primaryActionAccessibilityIdentifier,
            action: action,
            allowsImmediatePrimaryAction: true,
            onExceptionalReveal: onExceptionalReveal,
            contentTopPadding: TrinketDesign.Spacing.extraSmall,
            contentStackSpacing: TrinketDesign.Spacing.large,
            emptyExperience: {
                BattleOutcomeRewardRow(
                    icon: .system("star.fill"),
                    tint: .secondary,
                    text: String(localized: L10n.ui_victoryview_no_experience_awarded_de2bb),
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
                progressionBefore: summary.settlement.inputs.heroProgression,
                progressionAfter: summary.settlement.heroProgressionAfter,
                experienceAward: summary.settlement.award.heroExperience,
                accessibilityIdentifier: "\(summary.heroName) experience bar",
            ),
            .init(
                id: "companion",
                combatantName: summary.companionName,
                artworkName: summary.companionArtworkName,
                progressionBefore: summary.settlement.inputs.companionProgression,
                progressionAfter: summary.settlement.companionProgressionAfter,
                experienceAward: summary.settlement.award.companionExperience,
                accessibilityIdentifier: "\(summary.companionName) experience bar",
            ),
        ]
    }
}
