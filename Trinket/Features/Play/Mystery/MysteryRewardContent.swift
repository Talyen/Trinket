import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct MysteryRewardContent: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Bindable var session: MysteryEncounterSession
    let result: MysteryEffectApplyResult

    @State private var isCompleting = false
    @State private var completedExperienceBars = 0
    @State private var visibleWalletRewardCount = 0
    @State private var areItemsVisible = false
    @State private var isSequenceComplete = false
    @State private var hasStartedRewardSequence = false
    @State private var revealTask: Task<Void, Never>?
    @State private var selectedRewardItem: InventoryItem?

    var body: some View {
        RewardRevealShell(
            eyebrow: "MYSTERY EVENT",
            eyebrowAccessibilityIdentifier: nil,
            title: "Reward",
            subtitle: nil,
            titleAccessibilityIdentifier: AccessibilityID.Mystery.rewardTitle,
            titleColor: TrinketDesign.Colors.accent,
            content: {
                VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                    experiencePanel
                    revealedRewards
                }
            },
            primaryActionTitle: isSequenceComplete ? "Loot All" : nil,
            primaryActionAccessibilityIdentifier: AccessibilityID.Battle.continueButton,
            isPrimaryActionDisabled: isCompleting,
            onPrimaryAction: completeLootAll,
            contentTopPadding: TrinketDesign.Metrics.contentTopPadding + TrinketDesign.Metrics.mediumSpacing,
            contentStackSpacing: TrinketDesign.Metrics.sectionSpacing,
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
            if result.grantedExperience == 0 {
                startRewardSequence()
            }
        }
        .onDisappear {
            revealTask?.cancel()
            revealTask = nil
            if hasStartedRewardSequence {
                finishRewardSequence()
            }
        }
    }

    @ViewBuilder
    private var experiencePanel: some View {
        if result.grantedExperience > 0 {
            let hero = appState.roster.activeHero
            let companion = appState.roster.activeCompanion
            if let heroProgressionBefore = result.heroProgressionBefore,
               let heroProgressionAfter = result.heroProgressionAfter,
               let companionProgressionBefore = result.companionProgressionBefore,
               let companionProgressionAfter = result.companionProgressionAfter {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.largeSpacing) {
                    ExperienceBar(
                        combatantName: hero.name,
                        artworkName: hero.artReference?.thumbnailImageName ?? hero.artReference?.imageName,
                        pre: heroProgressionBefore,
                        post: heroProgressionAfter,
                        fillColor: TrinketDesign.Colors.progression,
                        experienceAward: result.grantedExperience,
                        snapToFinal: false,
                        onAnimationCompleted: experienceBarCompleted
                    )

                    ExperienceBar(
                        combatantName: companion.name,
                        artworkName: companion.artReference?.thumbnailImageName ?? companion.artReference?.imageName,
                        pre: companionProgressionBefore,
                        post: companionProgressionAfter,
                        fillColor: TrinketDesign.Colors.progression,
                        experienceAward: result.grantedExperience,
                        snapToFinal: false,
                        onAnimationCompleted: experienceBarCompleted
                    )
                }
                .trinketSurface(.secondary)
            }
        }
    }

    private var revealedRewards: some View {
        VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
            if !result.grantedItems.isEmpty {
                rewardItemPager
                    .opacity(areItemsVisible ? 1 : 0)
                    .scaleEffect(areItemsVisible ? 1 : 0.98)
                    .allowsHitTesting(areItemsVisible)
            }

            rewardWallet(columnCount: walletColumnCount)
        }
    }

    private var rewardItemPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: TrinketDesign.Metrics.largeSpacing) {
                ForEach(result.grantedItems) { item in
                    Button {
                        selectedRewardItem = item
                    } label: {
                        RewardItemRevealCard(item: item)
                    }
                    .trinketQuietTapButtonStyle()
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
        let materials = result.grantedMaterials.filter { $0.quantity > 0 }
        let rewardCount = (result.grantedGold > 0 ? 1 : 0) + materials.count

        if rewardCount > 0 {
            let goldOffset = result.grantedGold > 0 ? 1 : 0
            TrinketWalletGrid(columnCount: max(1, min(columnCount, rewardCount))) {
                if result.grantedGold > 0 {
                    TrinketWalletResourcePill(
                        title: "Gold",
                        amount: result.grantedGold,
                        showsIncreasePrefix: false
                    ) {
                        HomesteadResourceArtwork(resource: .gold)
                    }
                }

                ForEach(Array(materials.enumerated()), id: \.element.resource) { index, reward in
                    let revealIndex = index + goldOffset
                    TrinketWalletResourcePill(
                        title: reward.resource.displayName,
                        amount: reward.quantity,
                        showsIncreasePrefix: false
                    ) {
                        HomesteadResourceArtwork(resource: reward.resource)
                    }
                    .opacity(revealIndex == 0 || visibleWalletRewardCount > revealIndex ? 1 : 0)
                }
            }
            .opacity(visibleWalletRewardCount > 0 ? 1 : 0)
        }
    }

    private func completeLootAll() {
        guard isSequenceComplete, !isCompleting else { return }
        isCompleting = appState.finishActiveMysteryEncounter()
    }

    private func experienceBarCompleted() {
        completedExperienceBars += 1
        if completedExperienceBars >= 1 {
            startRewardSequence()
        }
    }

    private func startRewardSequence() {
        guard !hasStartedRewardSequence else { return }
        hasStartedRewardSequence = true
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            let clock = SuspendingClock()

            if !result.grantedItems.isEmpty || walletRewardCount == 0 {
                try? await clock.sleep(for: .seconds(TrinketMotion.Reward.itemRevealDelay))
                guard !Task.isCancelled else { return }
                withAnimation(TrinketMotion.Reward.reveal) {
                    areItemsVisible = true
                }
            }

            if walletRewardCount > 0 {
                for count in 1 ... walletRewardCount {
                    try? await clock.sleep(for: .seconds(TrinketMotion.Reward.resourceStagger))
                    guard !Task.isCancelled else { return }
                    withAnimation(TrinketMotion.Reward.stateChange) {
                        visibleWalletRewardCount = count
                    }
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
        (result.grantedGold > 0 ? 1 : 0) + result.grantedMaterials.filter { $0.quantity > 0 }.count
    }

    private var walletColumnCount: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : walletRewardCount
    }
}
