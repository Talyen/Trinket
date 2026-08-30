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

    @Bindable var session: MysteryEncounterSession
    let result: MysteryEffectApplyResult
    let onFinish: () -> Bool

    var body: some View {
        RewardRevealExperienceScreen(
            eyebrow: "MYSTERY",
            title: "Reward",
            titleAccessibilityIdentifier: AccessibilityID.Mystery.rewardTitle,
            hasExperienceAwards: result.hasGrantedExperience,
            loot: .init(
                items: result.grantedItems,
                gold: result.grantedGold,
                materials: result.grantedMaterials,
                showsIncreasePrefix: false,
                emptyMessage: nil,
                itemAccessibilityID: AccessibilityID.Mystery.rewardItem,
                lootSpacing: TrinketDesign.Metrics.sectionSpacing,
            ),
            primaryActionTitle: "Loot All",
            primaryActionAccessibilityIdentifier: AccessibilityID.Mystery.continueButton,
            onPrimaryAction: onFinish,
            contentTopPadding: TrinketDesign.Metrics.contentTopPadding + TrinketDesign.Metrics.mediumSpacing,
            contentStackSpacing: TrinketDesign.Metrics.sectionSpacing,
        ) { onExperienceBarCompleted in
            experiencePanel(onExperienceBarCompleted: onExperienceBarCompleted)
        }
    }

    @ViewBuilder
    private func experiencePanel(onExperienceBarCompleted: @escaping () -> Void) -> some View {
        if result.hasGrantedExperience {
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
                        experienceAward: result.heroGrantedExperience,
                        snapToFinal: false,
                        onAnimationCompleted: onExperienceBarCompleted,
                    )

                    ExperienceBar(
                        combatantName: companion.name,
                        artworkName: companion.artReference?.thumbnailImageName ?? companion.artReference?.imageName,
                        pre: companionProgressionBefore,
                        post: companionProgressionAfter,
                        fillColor: TrinketDesign.Colors.accentEmphasized,
                        experienceAward: result.companionGrantedExperience,
                        snapToFinal: false,
                        onAnimationCompleted: onExperienceBarCompleted,
                    )
                }
                .trinketSurface(.secondary)
            }
        }
    }
}
