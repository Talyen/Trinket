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
    let result: MysteryEffectResult
    let onFinish: () -> Bool

    var body: some View {
        RewardRevealExperienceScreen(
            eyebrow: "MYSTERY",
            title: "Reward",
            titleAccessibilityIdentifier: AccessibilityID.Mystery.rewardTitle,
            experienceAwards: experienceAwards,
            loot: .init(
                items: result.grantedItems,
                gold: result.grantedGold,
                materials: result.grantedMaterials,
                showsIncreasePrefix: false,
                emptyMessage: nil,
                itemAccessibilityID: AccessibilityID.Mystery.rewardItem,
                lootSpacing: TrinketDesign.Layout.sectionSpacing,
            ),
            primaryActionTitle: "Loot All",
            primaryActionAccessibilityIdentifier: AccessibilityID.Mystery.continueButton,
            onPrimaryAction: onFinish,
            contentTopPadding: TrinketDesign.Layout.contentTopPadding + TrinketDesign.Spacing.medium,
            contentStackSpacing: TrinketDesign.Layout.sectionSpacing,
        )
    }

    private var experienceAwards: [RewardRevealExperienceAward] {
        guard result.hasGrantedExperience,
              let heroProgressionBefore = result.heroProgressionBefore,
              let heroProgressionAfter = result.heroProgressionAfter,
              let companionProgressionBefore = result.companionProgressionBefore,
              let companionProgressionAfter = result.companionProgressionAfter
        else {
            return []
        }
        let hero = playerSave.roster.activeHero
        let companion = playerSave.roster.activeCompanion
        return [
            .init(
                id: "hero",
                combatantName: hero.name,
                artworkName: hero.artReference?.thumbnailImageName ?? hero.artReference?.imageName,
                progressionBefore: heroProgressionBefore,
                progressionAfter: heroProgressionAfter,
                experienceAward: result.heroGrantedExperience,
                accessibilityIdentifier: nil,
            ),
            .init(
                id: "companion",
                combatantName: companion.name,
                artworkName: companion.artReference?.thumbnailImageName ?? companion.artReference?.imageName,
                progressionBefore: companionProgressionBefore,
                progressionAfter: companionProgressionAfter,
                experienceAward: result.companionGrantedExperience,
                accessibilityIdentifier: nil,
            ),
        ]
    }
}
