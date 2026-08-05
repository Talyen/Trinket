import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct MysteryChoiceCard: View {
    @Environment(PlayerSaveStore.self) private var playerSave

    let choice: MysteryChoice
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
                Text(choice.label)
                    .trinketTypography(.rowTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                rewards
            }
            .padding(TrinketDesign.Metrics.largeSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                TrinketDesign.Colors.panel.opacity(isSelected ? 0.9 : 0.72),
                in: TrinketDesign.cardShape
            )
            .trinketMaterial(.subtleOverlay)
            .overlay {
                TrinketDesign.cardShape
                    .strokeBorder(
                        isSelected ? TrinketDesign.Colors.accent : TrinketDesign.Colors.subtleStroke,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .shadow(
                color: isSelected ? TrinketDesign.Colors.accent.opacity(0.2) : .clear,
                radius: 10,
                y: 2
            )
        }
        .trinketQuietTapButtonStyle()
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
        HStack(alignment: .center, spacing: TrinketDesign.Metrics.mediumSpacing) {
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
                        minimum: TrinketDesign.Metrics.mysteryRewardArtworkSize * 2.5,
                        maximum: 200
                    ),
                    spacing: TrinketDesign.Metrics.smallSpacing
                ),
            ],
            spacing: TrinketDesign.Metrics.smallSpacing
        ) {
            ForEach(Array(choice.effects.enumerated()), id: \.offset) { _, effect in
                reward(for: effect)
            }
        }
    }

    @ViewBuilder
    // swiftlint:disable:next function_body_length
    private func reward(for effect: MysteryEffect) -> some View {
        switch effect {
        case let .gainGold(amount):
            rewardSummary(
                title: "Gold",
                value: "+\(playerSave.homestead.effects.adjustedGold(amount))",
                resource: .gold,
                tint: HomesteadResource.gold.tint
            )

        case let .gainMaterial(resource, amount):
            rewardSummary(
                title: resource.displayName,
                value: "+\(amount)",
                resource: resource,
                tint: resource.tint
            )

        case let .gainExperience(amount):
            rewardSummary(
                title: "XP",
                value: "+\(amount)",
                systemIcon: "star.fill",
                tint: TrinketDesign.Colors.warning
            )

        case let .gainGeneratedItem(baseTypeID, guaranteedAffixIDs):
            rewardSummary(
                title: generatedItemRewardText(
                    baseTypeID: baseTypeID,
                    guaranteedAffixIDs: guaranteedAffixIDs
                ),
                value: nil,
                systemIcon: "gift.fill",
                tint: HomesteadResource.gold.tint
            )

        case .gainRandomItem:
            rewardSummary(
                title: "Random Item",
                value: nil,
                systemIcon: "shippingbox.fill",
                tint: TrinketDesign.Colors.encounterEvent
            )

        case .chooseItem:
            rewardSummary(
                title: "Choose Item",
                value: "1 of \(MysteryEffectApplier.chooseItemCandidateCount)",
                systemIcon: "square.grid.2x2.fill",
                tint: TrinketDesign.Colors.encounterEvent
            )

        case let .unlockCombatant(combatantID):
            rewardSummary(
                title: combatantName(id: combatantID),
                value: "Unlock",
                systemIcon: "person.crop.circle.badge.plus",
                tint: TrinketDesign.Colors.accent
            )

        case .corruptItem:
            rewardSummary(
                title: "Corrupt Item",
                value: "Risk",
                systemIcon: "flame.fill",
                tint: TrinketDesign.Colors.destructive
            )

        case .leave:
            rewardSummary(
                title: "Walk Away",
                value: "Safe",
                systemIcon: "figure.walk",
                tint: .secondary
            )
        }
    }

    private func rewardSummary(
        title: String,
        value: String? = nil,
        resource: HomesteadResource? = nil,
        systemIcon: String? = nil,
        tint: Color
    ) -> some View {
        HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            if let resource {
                HomesteadResourceArtwork(resource: resource)
                    .frame(
                        width: TrinketDesign.Metrics.mysteryRewardArtworkSize,
                        height: TrinketDesign.Metrics.mysteryRewardArtworkSize
                    )
            } else if let systemIcon {
                Image(systemName: systemIcon)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(
                        width: TrinketDesign.Metrics.mysteryRewardArtworkSize,
                        height: TrinketDesign.Metrics.mysteryRewardArtworkSize
                    )
            }

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.tightSpacing) {
                if let value {
                    Text(title)
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(value)
                        .trinketTypography(.rowTitle)
                        .monospacedDigit()
                } else {
                    Text(title)
                        .trinketTypography(.rowTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: TrinketDesign.Metrics.mysteryRewardRowMinHeight,
            alignment: .leading
        )
    }

    private func generatedItemRewardText(
        baseTypeID: String,
        guaranteedAffixIDs: [String]
    ) -> String {
        let itemName = GameContent.itemBaseTypes.first { $0.id == baseTypeID }?.name ?? "Item"
        let guaranteedAffixes = guaranteedAffixIDs.compactMap {
            GameContent.itemAffixDefinition(matching: $0)?.title
        }
        let affixText = guaranteedAffixes.map { "\($0) guaranteed" }
        return ([itemName] + affixText).joined(separator: " • ")
    }

    private func combatantName(id: String) -> String {
        let combatant = (GameContent.heroes + GameContent.companions).first { $0.id == id }
        return combatant?.name ?? "Combatant"
    }
}
