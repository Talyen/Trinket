import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct MysteryRewardContent: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Bindable var session: MysteryEncounterSession
    let result: MysteryEffectApplyResult
    let onFinish: () -> Bool

    @State private var isCompleting = false
    @State private var completedExperienceBars = 0
    @State private var revealSequence = RewardRevealSequenceState()
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
                    RewardRevealLootSection(
                        items: result.grantedItems,
                        gold: result.grantedGold,
                        materials: result.grantedMaterials,
                        showsIncreasePrefix: false,
                        emptyMessage: nil,
                        itemAccessibilityID: AccessibilityID.Battle.rewardItem,
                        areItemsVisible: revealSequence.areItemsVisible,
                        visibleWalletRewardCount: revealSequence.visibleWalletRewardCount,
                        walletColumnCount: walletColumnCount,
                        spacing: TrinketDesign.Metrics.sectionSpacing,
                        onSelectItem: { selectedRewardItem = $0 }
                    )
                }
            },
            primaryActionTitle: revealSequence.isSequenceComplete ? "Loot All" : nil,
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
            revealSequence.cancel(walletCount: walletRewardCount)
        }
    }

    @ViewBuilder
    private var experiencePanel: some View {
        if result.grantedExperience > 0 {
            let hero = playerSave.roster.activeHero
            let companion = playerSave.roster.activeCompanion
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
                        fillColor: TrinketDesign.Colors.accentEmphasized,
                        experienceAward: result.grantedExperience,
                        snapToFinal: false,
                        onAnimationCompleted: experienceBarCompleted
                    )

                    ExperienceBar(
                        combatantName: companion.name,
                        artworkName: companion.artReference?.thumbnailImageName ?? companion.artReference?.imageName,
                        pre: companionProgressionBefore,
                        post: companionProgressionAfter,
                        fillColor: TrinketDesign.Colors.accentEmphasized,
                        experienceAward: result.grantedExperience,
                        snapToFinal: false,
                        onAnimationCompleted: experienceBarCompleted
                    )
                }
                .trinketSurface(.secondary)
            }
        }
    }

    private func completeLootAll() {
        guard revealSequence.isSequenceComplete, !isCompleting else { return }
        isCompleting = onFinish()
    }

    private func experienceBarCompleted() {
        completedExperienceBars += 1
        if completedExperienceBars >= 1 {
            startRewardSequence()
        }
    }

    private func startRewardSequence() {
        revealSequence.start(
            itemCount: result.grantedItems.count,
            walletCount: walletRewardCount
        )
    }

    private var walletRewardCount: Int {
        (result.grantedGold > 0 ? 1 : 0) + result.grantedMaterials.count(where: { $0.quantity > 0 })
    }

    private var walletColumnCount: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : walletRewardCount
    }
}
