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

    @ScaledMetric(relativeTo: .body)
    private var baseItemArtworkSize: CGFloat = 64

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.largeSpacing) {
                ZStack(alignment: .leading) {
                    Text(choice.label)
                        .trinketTypography(.rowTitle)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? TrinketDesign.Colors.accent : .secondary)
                        .accessibilityHidden(true)
                }

                choiceDivider
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

    private var choiceDivider: some View {
        HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            Rectangle()
                .fill(TrinketDesign.Colors.subtleStroke)
                .frame(height: 1)

            Image(systemName: "diamond.fill")
                .font(.caption2)
                .foregroundStyle(
                    isSelected
                        ? TrinketDesign.Colors.accent
                        : TrinketDesign.Colors.subtleStroke
                )
                .accessibilityHidden(true)

            Rectangle()
                .fill(TrinketDesign.Colors.subtleStroke)
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var rewards: some View {
        ViewThatFits(in: .horizontal) {
            rewardRow
            rewardGrid
        }
        .padding(.horizontal, TrinketDesign.Metrics.mediumSpacing)
        .padding(.vertical, TrinketDesign.Metrics.largeSpacing)
        .frame(maxWidth: .infinity)
        .background(
            TrinketDesign.Colors.canvas.opacity(0.42),
            in: TrinketDesign.cardShape
        )
        .trinketMaterial(.subtleOverlay)
    }

    private var rewardRow: some View {
        HStack(alignment: .top, spacing: TrinketDesign.Metrics.smallSpacing) {
            ForEach(Array(choice.effects.enumerated()), id: \.offset) { index, effect in
                if index > 0 {
                    Divider()
                        .frame(minHeight: 86)
                        .padding(.vertical, TrinketDesign.Metrics.smallSpacing)
                }

                reward(for: effect)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var rewardGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: 88, maximum: 160),
                    spacing: TrinketDesign.Metrics.mediumSpacing
                ),
            ],
            spacing: TrinketDesign.Metrics.mediumSpacing
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
                value: "\(playerSave.homestead.effects.adjustedGold(amount))",
                resource: .gold,
                tint: HomesteadResource.gold.tint
            )

        case let .gainMaterial(resource, amount):
            rewardSummary(
                title: resource.displayName,
                value: "\(amount)",
                resource: resource,
                tint: resource.tint
            )

        case let .gainExperience(amount):
            rewardSummary(
                title: "XP",
                value: "\(amount)",
                systemIcon: "star.fill",
                tint: TrinketDesign.Colors.warning
            )

        case let .gainGeneratedItem(baseTypeID, guaranteedAffixIDs):
            rewardSummary(
                title: generatedItemRewardText(
                    baseTypeID: baseTypeID,
                    guaranteedAffixIDs: guaranteedAffixIDs
                ),
                value: "1",
                baseTypeID: baseTypeID,
                tint: TrinketDesign.Colors.encounterEvent
            )

        case .gainRandomItem:
            rewardSummary(
                title: "Random Item",
                value: "1",
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
        value: String,
        resource: HomesteadResource? = nil,
        systemIcon: String? = nil,
        baseTypeID: String? = nil,
        tint: Color
    ) -> some View {
        VStack(alignment: .center, spacing: TrinketDesign.Metrics.tightSpacing) {
            if let baseTypeID {
                baseItemPreview(baseTypeID: baseTypeID, tint: tint)
            } else if let resource {
                HomesteadResourceArtwork(resource: resource)
                    .frame(
                        width: TrinketDesign.Metrics.walletResourceArtworkSize,
                        height: TrinketDesign.Metrics.walletResourceArtworkSize
                    )
            } else if let systemIcon {
                Image(systemName: systemIcon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(
                        width: TrinketDesign.Metrics.walletResourceArtworkSize,
                        height: TrinketDesign.Metrics.walletResourceArtworkSize
                    )
            }

            Text(title)
                .trinketTypography(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .trinketTypography(.statValue)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 112,
            alignment: .top
        )
    }

    @ViewBuilder
    private func baseItemPreview(baseTypeID: String, tint: Color) -> some View {
        if let art = GameContent.itemBaseTypes.first(where: { $0.id == baseTypeID })?.previewArtReference {
            ZStack {
                TrinketDesign.cardShape
                    .fill(TrinketDesign.Colors.canvas.opacity(0.45))

                Image.preparedAsset(named: art.imageName)
                    .resizable()
                    .scaledToFit()
                    .decorativePreparedArtwork()
                    .padding(TrinketDesign.Metrics.extraSmallSpacing)
            }
            .frame(width: baseItemArtworkSize, height: baseItemArtworkSize)
            .clipShape(TrinketDesign.cardShape)
            .overlay {
                TrinketDesign.cardShape.strokeBorder(tint.opacity(0.72), lineWidth: 1)
            }
            .accessibilityHidden(true)
        } else {
            Image(systemName: "shippingbox.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(
                    width: TrinketDesign.Metrics.walletResourceArtworkSize,
                    height: TrinketDesign.Metrics.walletResourceArtworkSize
                )
                .accessibilityHidden(true)
        }
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
