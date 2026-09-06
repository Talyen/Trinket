import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct MysterySpecialChoiceCard: View {
    let choice: MysteryChoice
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
                Text(balanced: choice.label)
                    .trinketTypography(.rowTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .trinketFittedText()
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
        .trinketSelectionCardButtonStyle()
        .animation(TrinketMotion.Interaction.selection, value: isSelected)
        .accessibilityIdentifier(AccessibilityID.Mystery.choiceButton(choiceID: choice.id))
        .disabled(isDisabled)
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
                value: "Unlock",
                systemIcon: "person.crop.circle.badge.plus",
                tint: TrinketDesign.Colors.accent,
            )

        case .corruptItem:
            rewardSummary(
                title: "Corrupt Item",
                value: "Risk",
                systemIcon: "flame.fill",
                tint: TrinketDesign.Colors.destructive,
            )

        case .gainItem, .gainGold, .gainMaterial, .gainExperience:
            EmptyView()

        case .leave:
            rewardSummary(
                title: "Walk Away",
                value: "Safe",
                systemIcon: "figure.walk",
                tint: .secondary,
            )
        }
    }

    private func rewardSummary(
        title: String,
        value: String? = nil,
        resource: HomesteadResource? = nil,
        systemIcon: String? = nil,
        tint: Color,
    ) -> some View {
        HStack(spacing: TrinketDesign.Spacing.medium) {
            if let resource {
                HomesteadResourceArtwork(resource: resource)
                    .frame(
                        width: TrinketDesign.Layout.mysteryRewardArtworkSize,
                        height: TrinketDesign.Layout.mysteryRewardArtworkSize,
                    )
            } else if let systemIcon {
                Image(systemName: systemIcon)
                    // UIStyleCheck: allow - SF Symbol glyph sizing, not copy
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
                    Text(balanced: title)
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(.secondary)
                        .trinketFittedText()

                    Text(balanced: value)
                        .trinketTypography(.rowTitle)
                        .monospacedDigit()
                        .trinketFittedText()
                } else {
                    Text(balanced: title)
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
        let combatant = (GameContent.heroes + GameContent.companions).first { $0.id == id }
        return combatant?.name ?? "Combatant"
    }
}
