import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct VictoryView: View {
    let enemyName: String
    let summary: BattleVictorySummary
    let primaryActionTitle: String
    let onPrimaryAction: () -> Bool

    @State private var isCompleting = false
    @State private var revealSequence = RewardRevealSequenceState()
    @State private var selectedRewardItem: InventoryItem?

    var body: some View {
        RewardRevealShell(
            eyebrow: nil,
            eyebrowAccessibilityIdentifier: nil,
            title: "Victory",
            subtitle: nil,
            titleAccessibilityIdentifier: AccessibilityID.Battle.victory,
            titleColor: TrinketDesign.Colors.accent,
            content: {
                VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
                    experiencePanel
                    RewardRevealLootSection(
                        items: summary.rewardItems,
                        gold: summary.totalGold,
                        materials: summary.materialRewards,
                        showsIncreasePrefix: true,
                        emptyMessage: "No additional rewards.",
                        itemAccessibilityID: AccessibilityID.Battle.rewardItem,
                        areItemsVisible: revealSequence.areItemsVisible,
                        visibleWalletRewardCount: revealSequence.visibleWalletRewardCount,
                        walletColumnCount: walletRewardCount,
                        onSelectItem: { selectedRewardItem = $0 }
                    )
                    .accessibilityIdentifier(AccessibilityID.Battle.rewards)
                }
            },
            primaryActionTitle: revealSequence.isSequenceComplete ? primaryActionTitle : nil,
            primaryActionAccessibilityIdentifier: primaryActionAccessibilityIdentifier,
            isPrimaryActionDisabled: isCompleting,
            onPrimaryAction: completeVictory,
            contentTopPadding: TrinketDesign.Metrics.smallSpacing,
            contentStackSpacing: TrinketDesign.Metrics.largeSpacing,
            pinsPrimaryActionToBottom: false,
            primaryActionWidthFraction: 0.5
        )
        .sheet(item: $selectedRewardItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .trinketDetailSheet()
        }
        .onAppear {
            if !summary.hasExperienceAwards {
                revealSequence.start(
                    itemCount: summary.rewardItems.count,
                    walletCount: walletRewardCount
                )
            }
        }
        .onDisappear {
            // Cancel without completion left Loot All / Continue locked when
            // @State survived (same class as ExperienceBar onDisappear snap).
            revealSequence.cancel(walletCount: walletRewardCount)
        }
    }

    @ViewBuilder
    private var experiencePanel: some View {
        if summary.hasExperienceAwards {
            let onExperienceBarCompleted = {
                revealSequence.experienceBarCompleted(
                    requiredCount: 2,
                    itemCount: summary.rewardItems.count,
                    walletCount: walletRewardCount
                )
            }
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

    private func completeVictory() {
        guard revealSequence.isSequenceComplete, !isCompleting else { return }
        isCompleting = onPrimaryAction()
    }

    private var walletRewardCount: Int {
        (summary.totalGold > 0 ? 1 : 0) + summary.materialRewards.count(where: { $0.quantity > 0 })
    }

    private var primaryActionAccessibilityIdentifier: String {
        primaryActionTitle == "Loot All"
            ? AccessibilityID.Battle.continueButton
            : "\(primaryActionTitle) Button"
    }
}
