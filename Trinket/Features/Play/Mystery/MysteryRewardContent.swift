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
    @State private var revealSequence = RewardRevealSequenceState()
    @State private var selectedRewardItem: InventoryItem?

    var body: some View {
        RewardRevealShell(
            eyebrow: "MYSTERY",
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
            if !result.hasGrantedExperience {
                revealSequence.start(
                    itemCount: result.grantedItems.count,
                    walletCount: walletRewardCount
                )
            }
        }
        .onDisappear {
            revealSequence.cancel(walletCount: walletRewardCount)
        }
    }

    @ViewBuilder
    private var experiencePanel: some View {
        if result.hasGrantedExperience {
            let hero = playerSave.roster.activeHero
            let companion = playerSave.roster.activeCompanion
            if let heroProgressionBefore = result.heroProgressionBefore,
               let heroProgressionAfter = result.heroProgressionAfter,
               let companionProgressionBefore = result.companionProgressionBefore,
               let companionProgressionAfter = result.companionProgressionAfter {
                let onExperienceBarCompleted = {
                    revealSequence.experienceBarCompleted(
                        requiredCount: 2,
                        itemCount: result.grantedItems.count,
                        walletCount: walletRewardCount
                    )
                }
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.largeSpacing) {
                    ExperienceBar(
                        combatantName: hero.name,
                        artworkName: hero.artReference?.thumbnailImageName ?? hero.artReference?.imageName,
                        pre: heroProgressionBefore,
                        post: heroProgressionAfter,
                        fillColor: TrinketDesign.Colors.accentEmphasized,
                        experienceAward: result.heroGrantedExperience,
                        snapToFinal: false,
                        onAnimationCompleted: onExperienceBarCompleted
                    )

                    ExperienceBar(
                        combatantName: companion.name,
                        artworkName: companion.artReference?.thumbnailImageName ?? companion.artReference?.imageName,
                        pre: companionProgressionBefore,
                        post: companionProgressionAfter,
                        fillColor: TrinketDesign.Colors.accentEmphasized,
                        experienceAward: result.companionGrantedExperience,
                        snapToFinal: false,
                        onAnimationCompleted: onExperienceBarCompleted
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

    private var walletRewardCount: Int {
        (result.grantedGold > 0 ? 1 : 0) + result.grantedMaterials.count(where: { $0.quantity > 0 })
    }

    private var walletColumnCount: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : walletRewardCount
    }
}
