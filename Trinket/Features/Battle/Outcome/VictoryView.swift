import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct VictoryView: View {
    let enemyName: String
    let summary: BattleVictorySummary
    let primaryActionTitle: String
    let onPrimaryAction: () -> Bool

    @State private var isCompleting = false
    @State private var completedExperienceBars = 0
    @State private var visibleWalletRewardCount = 0
    @State private var areItemsVisible = false
    @State private var isSequenceComplete = false
    @State private var hasStartedRewardSequence = false
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        RewardRevealShell(
            eyebrow: nil,
            eyebrowAccessibilityIdentifier: nil,
            title: "Victory",
            subtitle: nil,
            titleAccessibilityIdentifier: AccessibilityID.Battle.victory,
            titleColor: TrinketDesign.Colors.accent,
            content: {
                VStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
                    experiencePanel
                    revealedRewards
                }
            },
            primaryActionTitle: isSequenceComplete ? primaryActionTitle : nil,
            primaryActionAccessibilityIdentifier: primaryActionAccessibilityIdentifier,
            isPrimaryActionDisabled: isCompleting,
            onPrimaryAction: completeVictory,
            contentTopPadding: TrinketDesign.Metrics.smallSpacing,
            pinsPrimaryActionToBottom: false,
            primaryActionWidthFraction: 0.5
        )
        .onAppear {
            if !summary.hasExperienceAwards {
                startRewardSequence()
            }
        }
        .onDisappear {
            revealTask?.cancel()
            revealTask = nil
            // Cancel without completion left Loot All / Continue locked when
            // @State survived (same class as ExperienceBar onDisappear snap).
            if hasStartedRewardSequence {
                finishRewardSequence()
            }
        }
    }

    @ViewBuilder
    private var experiencePanel: some View {
        if summary.hasExperienceAwards {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
                ExperienceBar(
                    combatantName: summary.heroName,
                    artworkName: summary.heroArtworkName,
                    pre: summary.heroProgressionBefore,
                    post: summary.heroProgressionAfter,
                    fillColor: TrinketDesign.Colors.progression,
                    experienceAward: summary.experience,
                    snapToFinal: false,
                    onAnimationCompleted: experienceBarCompleted
                )
                .accessibilityIdentifier("\(summary.heroName) experience bar")

                ExperienceBar(
                    combatantName: summary.companionName,
                    artworkName: summary.companionArtworkName,
                    pre: summary.companionProgressionBefore,
                    post: summary.companionProgressionAfter,
                    fillColor: TrinketDesign.Colors.progression,
                    experienceAward: summary.companionExperience,
                    snapToFinal: false,
                    onAnimationCompleted: experienceBarCompleted
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

    private var revealedRewards: some View {
        VStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            rewardWallet(columnCount: walletRewardCount)

            if !summary.rewardItems.isEmpty {
                rewardItemPager
                    .opacity(areItemsVisible ? 1 : 0)
                    .scaleEffect(areItemsVisible ? 1 : 0.98)
            }
        }
        .accessibilityIdentifier(AccessibilityID.Battle.rewards)
    }

    private var rewardItemPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: TrinketDesign.Metrics.largeSpacing) {
                ForEach(summary.rewardItems) { item in
                    RewardItemRevealCard(item: item)
                        .containerRelativeFrame(.horizontal)
                        .accessibilityIdentifier(AccessibilityID.Battle.rewardItem(item.id))
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
    }

    @ViewBuilder
    private func rewardWallet(columnCount: Int) -> some View {
        let materials = summary.materialRewards.filter { $0.quantity > 0 }
        let rewardCount = (summary.totalGold > 0 ? 1 : 0) + materials.count

        if rewardCount > 0 {
            TrinketWalletGrid(columnCount: max(1, min(columnCount, rewardCount))) {
                if summary.totalGold > 0 {
                    TrinketWalletResourcePill(
                        title: "Gold",
                        amount: summary.totalGold,
                        showsIncreasePrefix: true
                    ) {
                        HomesteadResourceArtwork(resource: .gold)
                    }
                    .opacity(visibleWalletRewardCount > 0 ? 1 : 0)
                }

                ForEach(Array(materials.enumerated()), id: \.element.resource) { index, reward in
                    TrinketWalletResourcePill(
                        title: reward.resource.displayName,
                        amount: reward.quantity,
                        showsIncreasePrefix: true
                    ) {
                        HomesteadResourceArtwork(resource: reward.resource)
                    }
                    .opacity(visibleWalletRewardCount > index + (summary.totalGold > 0 ? 1 : 0) ? 1 : 0)
                }
            }
        } else if summary.rewardItems.isEmpty {
            Text("No additional rewards.")
                .trinketTypography(.secondaryBody)
                .foregroundStyle(.secondary)
                .opacity(areItemsVisible ? 1 : 0)
        }
    }

    private func completeVictory() {
        guard isSequenceComplete, !isCompleting else { return }
        isCompleting = onPrimaryAction()
    }

    private func experienceBarCompleted() {
        completedExperienceBars += 1
        if completedExperienceBars == 2 {
            startRewardSequence()
        }
    }

    private func startRewardSequence() {
        guard !hasStartedRewardSequence else { return }
        hasStartedRewardSequence = true
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            let clock = SuspendingClock()

            if walletRewardCount > 0 {
                for count in 1 ... walletRewardCount {
                    try? await clock.sleep(for: .seconds(TrinketMotion.Reward.resourceStagger))
                    guard !Task.isCancelled else { return }
                    withAnimation(TrinketMotion.Reward.stateChange) {
                        visibleWalletRewardCount = count
                    }
                }
            }

            if !summary.rewardItems.isEmpty || walletRewardCount == 0 {
                try? await clock.sleep(for: .seconds(TrinketMotion.Reward.itemRevealDelay))
                guard !Task.isCancelled else { return }
                withAnimation(TrinketMotion.Reward.reveal) {
                    areItemsVisible = true
                }
            }

            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.completionDelay))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.stateChange) {
                finishRewardSequence()
            }
            revealTask = nil
        }
    }

    private func finishRewardSequence() {
        guard !isSequenceComplete else { return }
        visibleWalletRewardCount = walletRewardCount
        areItemsVisible = true
        isSequenceComplete = true
    }

    private var walletRewardCount: Int {
        (summary.totalGold > 0 ? 1 : 0) + summary.materialRewards.filter { $0.quantity > 0 }.count
    }

    private var primaryActionAccessibilityIdentifier: String {
        primaryActionTitle == "Loot All"
            ? AccessibilityID.Battle.continueButton
            : "\(primaryActionTitle) Button"
    }
}

private struct RewardItemRevealCard: View {
    let item: InventoryItem

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            ItemArtwork(item: item, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: 234)
                .trinketArtworkBlend(.bottom(into: .canvas))
                .clipShape(TrinketDesign.cardShape)

            VStack(spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                TrinketRarityLabel(rarity: item.rarity)

                Text(item.displayName)
                    .trinketTypography(.sectionDisplay)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
