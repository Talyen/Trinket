import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct VictoryView: View {
    let enemyName: String
    let summary: BattleVictorySummary
    let primaryActionTitle: String
    let onPrimaryAction: () -> Void

    var body: some View {
        BattleOutcomeShell(
            symbolName: "checkmark.seal.fill",
            symbolColor: TrinketDesign.Colors.success,
            title: "Victory",
            subtitle: "\(enemyName) is defeated.",
            titleAccessibilityIdentifier: "Victory",
            content: {
                VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                    BattleOutcomeRewardSection(title: "Experience") {
                        experienceContent
                    }

                    BattleOutcomeRewardSection(title: "Rewards") {
                        rewardsContent
                    }
                }
            },
            primaryButtonTitle: primaryActionTitle,
            primaryButtonAccessibilityIdentifier: "\(primaryActionTitle) Button",
            primaryButtonTint: nil,
            onPrimaryAction: onPrimaryAction
        )
    }

    @ViewBuilder
    private var experienceContent: some View {
        if summary.hasExperienceAwards {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
                ExperienceBar(
                    combatantName: summary.heroName,
                    pre: summary.heroProgressionBefore,
                    post: summary.heroProgressionAfter,
                    fillColor: TrinketDesign.Colors.progression
                )
                .accessibilityIdentifier("\(summary.heroName) experience bar")

                ExperienceBar(
                    combatantName: summary.petName,
                    pre: summary.petProgressionBefore,
                    post: summary.petProgressionAfter,
                    fillColor: TrinketDesign.Colors.progression
                )
                .accessibilityIdentifier("\(summary.petName) experience bar")
            }
        } else {
            BattleOutcomeRewardRow(
                symbolName: "star",
                tint: .secondary,
                text: "No experience awarded."
            )
        }
    }

    @ViewBuilder
    private var rewardsContent: some View {
        if summary.totalGold > 0 {
            BattleOutcomeRewardRow(
                symbolName: Keyword.gold.visualStyle.symbolName,
                tint: Keyword.gold.visualStyle.color,
                text: "+\(summary.totalGold) Gold"
            )
        }

        ForEach(summary.materialRewards.filter { $0.quantity > 0 }, id: \.resource) { reward in
            BattleOutcomeRewardRow(
                symbolName: reward.resource.symbolName,
                tint: reward.resource.tint,
                text: "+\(reward.quantity) \(reward.resource.displayName)"
            )
        }

        if summary.itemNames.isEmpty {
            if summary.totalGold == 0, summary.materialRewards.allSatisfy({ $0.quantity <= 0 }) {
                BattleOutcomeRewardRow(
                    symbolName: "bag",
                    tint: .secondary,
                    text: "No items awarded."
                )
            }
        } else {
            ForEach(summary.itemNames, id: \.self) { itemName in
                BattleOutcomeRewardRow(
                    symbolName: "bag.fill",
                    tint: Color.accentColor,
                    text: itemName
                )
            }
        }
    }
}
