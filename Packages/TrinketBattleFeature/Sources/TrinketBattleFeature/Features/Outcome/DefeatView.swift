import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport

struct DefeatView: View {
    let configuration: BattleRunConfiguration
    let settlement: BattleRewardSettlement
    let didRetreat: Bool
    let onAction: (BattleDefeatAction) -> Bool

    @State private var isCompleting = false

    var body: some View {
        RewardRevealShell(
            eyebrow: nil,
            eyebrowAccessibilityIdentifier: nil,
            title: String(localized: L10n.ui_defeatview_defeat_2be4c),
            subtitle: didRetreat
                ? String(localized: L10n.ui_defeatview_your_party_retreated_from_1_86965("\(configuration.enemy?.name ?? "Enemy")"))
                : String(localized: L10n.ui_defeatview_your_party_fell_to_1_e9b8d("\(configuration.enemy?.name ?? "Enemy")")),
            titleAccessibilityIdentifier: AccessibilityID.Battle.defeat,
            titleColor: TrinketDesign.Colors.accent,
            content: {
                RewardRevealExperienceSection(awards: experienceAwards)
                    .accessibilityIdentifier(AccessibilityID.Battle.experience)
            },
            primaryActionTitle: String(localized: L10n.ui_defeatview_continue_31fbe),
            primaryActionAccessibilityIdentifier: AccessibilityID.Battle.defeatLeaveButton,
            isPrimaryActionDisabled: isCompleting,
            onPrimaryAction: { complete(.leave) },
            contentTopPadding: TrinketDesign.Spacing.extraSmall,
            contentStackSpacing: TrinketDesign.Spacing.large,
            pinsPrimaryActionToBottom: false,
        )
    }

    private func complete(_ action: BattleDefeatAction) {
        guard !isCompleting else { return }
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
