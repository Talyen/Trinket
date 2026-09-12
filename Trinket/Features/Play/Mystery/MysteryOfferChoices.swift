import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct MysteryOfferChoices: View {
    let offers: [MysteryOffer]
    let choices: [MysteryChoice]
    let width: CGFloat
    let preparedArtworkNames: [String]
    let isDisabled: Bool
    let onInspect: (InventoryItem) -> Void
    let onChoose: (String) -> Void

    private var columnWidth: CGFloat {
        max(0, (width - TrinketDesign.Spacing.medium) / 2)
    }

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: TrinketDesign.Spacing.medium, verticalSpacing: TrinketDesign.Spacing.medium) {
            GridRow {
                ForEach(offers, id: \.choiceID) { offer in
                    artwork(for: offer)
                        .frame(width: columnWidth)
                }
            }
            GridRow {
                ForEach(offers, id: \.choiceID) { offer in
                    ItemCardLabel(item: offer.item)
                        .padding(.horizontal, TrinketDesign.Spacing.extraSmall)
                        .frame(width: columnWidth)
                }
            }
            GridRow {
                ForEach(offers, id: \.choiceID) { offer in
                    bonus(offer.bonus)
                        .frame(width: columnWidth)
                }
            }
            GridRow {
                ForEach(offers, id: \.choiceID) { offer in
                    Button {
                        onChoose(offer.choiceID)
                    } label: {
                        Text(choices.first { $0.id == offer.choiceID }?.label ?? "Choose")
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.Mystery.choiceButton(choiceID: offer.choiceID))
                    .frame(width: columnWidth)
                    .disabled(isDisabled)
                }
            }
        }
        .frame(width: width)
    }

    private func artwork(for offer: MysteryOffer) -> some View {
        Button {
            onInspect(offer.item)
        } label: {
            TrinketDesign.cardShape
                .fill(TrinketDesign.Colors.surface)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    if let name = offer.item.artReference?.imageName, preparedArtworkNames.contains(name) {
                        ItemArtwork(item: offer.item)
                            .clipShape(TrinketDesign.cardShape)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Inspect \(offer.item.displayName)")
        .accessibilityIdentifier(AccessibilityID.Mystery.offerArtwork(choiceID: offer.choiceID))
        .disabled(isDisabled)
    }

    private func bonus(_ reward: MysteryRewardBonus) -> some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            switch reward {
            case let .gold(amount):
                HomesteadResourceArtwork(resource: .gold)
                    .frame(width: TrinketDesign.Spacing.extraLarge, height: TrinketDesign.Spacing.extraLarge)
                Text("+\(amount) Gold")
                    .trinketTypography(.statValue)
                    .fixedSize(horizontal: false, vertical: true)
            case let .material(resource, amount):
                TrinketWalletResourcePill(
                    title: resource.displayName,
                    amount: amount,
                    showsIncreasePrefix: true,
                ) {
                    HomesteadResourceArtwork(resource: resource)
                }
            case let .experience(amount):
                TrinketWalletResourcePill(
                    title: "Experience",
                    amount: amount,
                    showsIncreasePrefix: true,
                ) {
                    ExperienceArtwork()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TrinketDesign.Spacing.small)
        .trinketSurface(.secondary)
    }
}
