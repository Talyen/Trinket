import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct MysteryOfferChoices: View {
    @Environment(\.locale) private var locale
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
        Grid(alignment: .topLeading, horizontalSpacing: TrinketDesign.Spacing.medium, verticalSpacing: TrinketDesign.Spacing.small) {
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
                        GameLabel(choices.first { $0.id == offer.choiceID }?
                            .label ?? String(localized: L10n.ui_mysteryofferchoices_choose_c7f93))
                            .trinketSingleLineFittedText()
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
            ProductCardShell(
                showsLabel: false,
                reservesLabelSpace: false,
                art: {
                    if let name = offer.item.artReference?.imageName, preparedArtworkNames.contains(name) {
                        ItemArtwork(item: offer.item)
                    }
                },
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.ui_mysteryofferchoices_inspect_1_c8b12("\(offer.item.localizedDisplayName(locale: locale))")))
        .accessibilityIdentifier(AccessibilityID.Mystery.offerArtwork(choiceID: offer.choiceID))
        .disabled(isDisabled)
    }

    private func bonus(_ reward: MysteryRewardBonus) -> some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            switch reward {
            case let .gold(amount):
                TrinketWalletResourcePill(
                    title: String(localized: L10n.ui_mysteryofferchoices_gold_6249d),
                    amount: amount,
                    showsIncreasePrefix: true,
                ) {
                    HomesteadResourceArtwork(resource: .gold)
                }
            case let .goldAndExperience(gold, experience, _, _):
                TrinketWalletResourcePill(
                    title: String(localized: L10n.ui_mysteryofferchoices_gold_6249d),
                    amount: gold,
                    showsIncreasePrefix: true,
                ) {
                    HomesteadResourceArtwork(resource: .gold)
                }
                TrinketWalletResourcePill(
                    title: String(localized: L10n.ui_mysteryofferchoices_exp_da8a9),
                    amount: experience,
                    showsIncreasePrefix: true,
                ) {
                    ExperienceArtwork()
                }
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
                    title: String(localized: L10n.ui_mysteryofferchoices_exp_da8a9),
                    amount: amount,
                    showsIncreasePrefix: true,
                ) {
                    ExperienceArtwork()
                }
            }
        }
        .padding(.horizontal, TrinketDesign.Spacing.medium)
        .padding(.vertical, TrinketDesign.Spacing.extraSmall)
        .trinketMaterial(.bottomBar)
    }
}
