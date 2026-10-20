import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct MysterySpecialChoiceCard: View {
    let choice: MysteryChoice
    let isSelected: Bool
    let isDisabled: Bool
    var isUnavailable = false
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
                GameLabel(choice.label)
                    .trinketTypography(.rowTitle)
                    .foregroundStyle(.primary)
                    .trinketSingleLineFittedText()
                    .frame(maxWidth: .infinity, alignment: .leading)

                rewards
            }
            .padding(TrinketDesign.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                TrinketDesign.Colors.panel.opacity(isSelected ? 0.9 : 0.72),
                in: TrinketDesign.cardShape,
            )
            .trinketMaterial(.subtleOverlay)
            .overlay {
                TrinketDesign.cardShape
                    .strokeBorder(
                        isSelected ? TrinketDesign.Colors.accent : TrinketDesign.Colors.subtleStroke,
                        lineWidth: isSelected ? 1.5 : 1,
                    )
            }
            .shadow(
                color: isSelected ? TrinketDesign.Colors.accent.opacity(0.2) : .clear,
                radius: 10,
                y: 2,
            )
        }
        .trinketArtworkCardButtonStyle()
        .animation(TrinketMotion.Interaction.selection, value: isSelected)
        .opacity(isUnavailable ? 0.5 : 1)
        .accessibilityIdentifier(AccessibilityID.Mystery.choiceButton(choiceID: choice.id))
        .disabled(isDisabled || isUnavailable)
    }

    private var rewards: some View {
        ViewThatFits(in: .horizontal) {
            rewardRow
            rewardGrid
        }
        .frame(maxWidth: .infinity)
    }

    private var rewardRow: some View {
        HStack(alignment: .center, spacing: TrinketDesign.Spacing.medium) {
            ForEach(Array(choice.effects.enumerated()), id: \.offset) { _, effect in
                reward(for: effect)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var rewardGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: TrinketDesign.Layout.mysteryRewardArtworkSize * 2.5,
                        maximum: 200,
                    ),
                    spacing: TrinketDesign.Spacing.small,
                ),
            ],
            spacing: TrinketDesign.Spacing.small,
        ) {
            ForEach(Array(choice.effects.enumerated()), id: \.offset) { _, effect in
                reward(for: effect)
            }
        }
    }

    @ViewBuilder
    private func reward(for effect: MysteryEffect) -> some View {
        switch effect {
        case let .unlockCombatant(combatantID):
            rewardSummary(
                title: combatantName(id: combatantID),
                value: String(localized: L10n.ui_mysteryspecialchoicecard_unlock_4ac70),
                icon: .system("person.badge.plus"),
                tint: TrinketDesign.Colors.accent,
            )

        case .corruptItem:
            rewardSummary(
                title: String(localized: L10n.ui_mysteryspecialchoicecard_corrupt_item_86c3d),
                value: String(localized: L10n.ui_mysteryspecialchoicecard_risk_0711a),
                icon: .system("dice.fill"),
                tint: TrinketDesign.Colors.destructive,
            )

        case .gainItem, .gainGold, .gainMaterial, .gainExperience:
            EmptyView()

        case .leave:
            rewardSummary(
                title: String(localized: L10n.ui_mysteryspecialchoicecard_walk_away_85010),
                value: String(localized: L10n.ui_mysteryspecialchoicecard_safe_4f9f0),
                icon: .system("figure.walk"),
                tint: .secondary,
            )
        }
    }

    private func rewardSummary(
        title: String,
        value: String? = nil,
        resource: HomesteadResource? = nil,
        icon: GameIcon? = nil,
        tint: Color,
    ) -> some View {
        HStack(spacing: TrinketDesign.Spacing.medium) {
            if let resource {
                HomesteadResourceArtwork(resource: resource)
                    .frame(
                        width: TrinketDesign.Layout.mysteryRewardArtworkSize,
                        height: TrinketDesign.Layout.mysteryRewardArtworkSize,
                    )
            } else if let icon {
                GameIconImage(icon)
                    // UIStyleCheck: allow - Game icon glyph sizing, not copy
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                    .frame(
                        width: TrinketDesign.Layout.mysteryRewardArtworkSize,
                        height: TrinketDesign.Layout.mysteryRewardArtworkSize,
                    )
            }

            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
                if let value {
                    GameLabel(title, balanced: true)
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(.secondary)
                        .trinketFittedText()

                    GameLabel(value, balanced: true)
                        .trinketTypography(.rowTitle)
                        .monospacedDigit()
                        .trinketFittedText()
                } else {
                    GameLabel(title, balanced: true)
                        .trinketTypography(.rowTitle)
                        .foregroundStyle(.primary)
                        .trinketFittedText()
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: TrinketDesign.Layout.mysteryRewardRowMinHeight,
            alignment: .leading,
        )
    }

    private func combatantName(id: String) -> String {
        GameContent.combatant(matching: id)?.name ?? String(localized: L10n.ui_mysteryspecialchoicecard_combatant_d1bd7)
    }
}
