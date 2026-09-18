import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport

struct DefeatView: View {
    let configuration: BattleRunConfiguration
    let settlement: BattleRewardSettlement
    let onAction: (BattleDefeatAction) -> Bool

    @State private var completedExperienceBars = 0
    @State private var isCompleting = false

    var body: some View {
        RewardRevealShell(
            eyebrow: nil,
            eyebrowAccessibilityIdentifier: nil,
            title: "Defeat",
            subtitle: "Your party fell to \(configuration.enemy?.name ?? "Enemy").",
            titleAccessibilityIdentifier: AccessibilityID.Battle.defeat,
            titleColor: TrinketDesign.Colors.accent,
            content: {
                RewardRevealExperienceSection(awards: experienceAwards) {
                    completedExperienceBars += 1
                }
                .accessibilityIdentifier(AccessibilityID.Battle.experience)
            },
            primaryActionTitle: "Retry",
            primaryActionAccessibilityIdentifier: AccessibilityID.Battle.defeatPrimaryButton,
            isPrimaryActionDisabled: isCompleting || completedExperienceBars < experienceAwards.count,
            onPrimaryAction: { complete(.retry) },
            secondaryActionTitle: "Leave",
            secondaryActionAccessibilityIdentifier: AccessibilityID.Battle.defeatLeaveButton,
            onSecondaryAction: { complete(.leave) },
            contentTopPadding: TrinketDesign.Spacing.extraSmall,
            contentStackSpacing: TrinketDesign.Spacing.large,
            pinsPrimaryActionToBottom: false,
        )
    }

    private func complete(_ action: BattleDefeatAction) {
        guard !isCompleting, completedExperienceBars >= experienceAwards.count else { return }
        isCompleting = true
        isCompleting = onAction(action)
    }

    private var experienceAwards: [RewardRevealExperienceAward] {
        battleExperienceAwards(
            hero: .init(
                id: "hero", combatantName: configuration.hero.combatant.name,
                artworkName: configuration.hero.combatant.artReference?.thumbnailImageName,
                progressionBefore: settlement.inputs.heroProgression,
                progressionAfter: settlement.heroProgressionAfter,
                experienceAward: settlement.award.heroExperience,
            ),
            companion: .init(
                id: "companion", combatantName: configuration.companion.combatant.name,
                artworkName: configuration.companion.combatant.artReference?.thumbnailImageName,
                progressionBefore: settlement.inputs.companionProgression,
                progressionAfter: settlement.companionProgressionAfter,
                experienceAward: settlement.award.companionExperience,
            ),
        )
    }
}
