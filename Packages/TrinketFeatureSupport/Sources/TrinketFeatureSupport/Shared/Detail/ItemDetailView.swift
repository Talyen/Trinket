import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public enum ItemSalvageActionResult: Equatable, Sendable {
    case success(yields: [ResourceAmount])
    case itemNotFound
    case persistenceFailure
}

public struct ItemDetailView: View {
    @Environment(\.locale) private var locale
    private struct SalvageConfiguration {
        let yields: [ResourceAmount]
        let equippedByName: String?
        let onSalvage: () -> ItemSalvageActionResult
        let onSalvageFinished: ((ItemSalvageActionResult) -> Void)?
    }

    @Environment(\.dismiss) private var dismiss

    let item: InventoryItem
    private let primaryAction: DetailPrimaryAction?
    private let salvage: SalvageConfiguration?
    private var heroNote: String?
    private var heroNoteAccessibilityID: String?

    @State private var isSalvageConfirmationPresented = false

    public init(
        item: InventoryItem,
        heroNote: String? = nil,
        heroNoteAccessibilityID: String? = nil,
    ) {
        self.item = item
        primaryAction = nil
        salvage = nil
        self.heroNote = heroNote
        self.heroNoteAccessibilityID = heroNoteAccessibilityID
    }

    public init(
        item: InventoryItem,
        purchasePrice: Int,
        canAfford: Bool = true,
        isPurchaseDisabled: Bool = false,
        purchaseButtonTitleOverride: String? = nil,
        accessibilityIdentifier: String = AccessibilityID.Shop.detailBuyButton,
        onPurchase: @escaping () -> Void,
    ) {
        self.item = item
        primaryAction = DetailPrimaryAction(
            title: purchaseButtonTitleOverride
                ??
                (canAfford ? String(localized: L10n.ui_itemdetailview_buy_for_1_gold_13d40("\(purchasePrice)")) :
                    String(localized: L10n.ui_itemdetailview_need_1_gold_341f4("\(purchasePrice)"))),
            accessibilityIdentifier: accessibilityIdentifier,
            isDisabled: !canAfford || isPurchaseDisabled,
            action: onPurchase,
        )
        salvage = nil
    }

    public init(
        item: InventoryItem,
        primaryActionTitle: String,
        primaryActionAccessibilityID: String? = nil,
        onPrimaryAction: @escaping () -> Void,
    ) {
        self.item = item
        primaryAction = DetailPrimaryAction(
            title: primaryActionTitle,
            accessibilityIdentifier: primaryActionAccessibilityID,
            action: onPrimaryAction,
        )
        salvage = nil
    }

    public init(
        item: InventoryItem,
        salvageYields: [ResourceAmount],
        equippedByName: String? = nil,
        onSalvage: @escaping () -> ItemSalvageActionResult,
        onSalvageFinished: ((ItemSalvageActionResult) -> Void)? = nil,
    ) {
        self.item = item
        primaryAction = nil
        salvage = SalvageConfiguration(
            yields: salvageYields,
            equippedByName: equippedByName,
            onSalvage: onSalvage,
            onSalvageFinished: onSalvageFinished,
        )
    }

    private var showsSalvageAction: Bool {
        guard salvage != nil else { return false }
        return !item.isTrinket && item.rarity != .unique
    }

    public var body: some View {
        GeometryReader { geometry in
            DetailHeroScrollShell(
                title: item.localizedDisplayName(locale: locale),
                header: { baseHeight in
                    DetailHeroHeader(
                        eyebrow: eyebrow(for: item),
                        title: item.localizedDisplayName(locale: locale),
                        titleShine: item.displayTextShine,
                        baseHeight: baseHeight,
                    ) {
                        ItemArtwork(item: item)
                    } footer: {
                        if let heroNote {
                            Label(heroNote, systemImage: "checkmark.circle.fill")
                                .trinketTypography(.rowTitle)
                                .trinketOnArtText(.eyebrow)
                                .accessibilityIdentifier(heroNoteAccessibilityID ?? heroNote)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemDetail(item.id))
                },
                bodyContent: {
                    traitsSection
                },
            )
            .sizingHero(in: geometry.size, primaryAction: primaryAction)
        }
        // Pushed details reserve a navigation bar; inspection roots may not.
        .ignoresSafeArea(edges: .top)
    }

    private func eyebrow(for item: InventoryItem) -> String {
        let tag = item.isTrinket
            ? String(localized: L10n.ui_itemdetailview_trinket_6faed)
            : LocalizedGameText(CoreCopy.resource(item.rarity.label), locale: locale).text
        return item.isCorrupted ? String(localized: L10n.ui_itemdetailview_1_corrupted_7db4d("\(tag)")) : tag
    }

    @ViewBuilder
    private var traitsSection: some View {
        DetailSection(String(localized: L10n.ui_itemdetailview_traits_e0ab4)) {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                ForEach(Array(item.displayedAffixes.enumerated()), id: \.element.id) { index, affix in
                    if item.inscribedAffixIndex == index {
                        Text(L10n.homestead_inscribed).trinketTypography(.eyebrow).foregroundStyle(.secondary)
                    }
                    DetailTraitRow(
                        title: affix.title,
                        description: affix.description,
                        titleShine: item.affixShine(at: index, affix: affix),
                    )
                }
            }
        }

        if showsSalvageAction {
            VStack(spacing: TrinketDesign.Spacing.medium) {
                if isSalvageConfirmationPresented {
                    salvageMaterialPreview
                    Button(String(localized: L10n.ui_itemdetailview_cancel_19766)) { isSalvageConfirmationPresented = false }
                        .trinketSecondaryActionButton(accessibilityIdentifier: AccessibilityID.Collection.salvageCancelButton)
                    Button(String(localized: L10n.ui_itemdetailview_salvage_75f34), role: .destructive) {
                        guard isSalvageConfirmationPresented else { return }
                        isSalvageConfirmationPresented = false
                        confirmSalvage()
                    }
                    .trinketPrimaryActionButton(
                        tint: TrinketDesign.Colors.destructive,
                        accessibilityIdentifier: AccessibilityID.Collection.salvageConfirmButton,
                    )
                } else {
                    Button(String(localized: L10n.ui_itemdetailview_salvage_75f34)) { isSalvageConfirmationPresented = true }
                        .trinketSecondaryActionButton(
                            tint: TrinketDesign.Colors.destructive,
                            accessibilityIdentifier: AccessibilityID.Collection.salvageButton,
                        )
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, TrinketDesign.Layout.sectionSpacing)
        }
    }

    @ViewBuilder
    private var salvageMaterialPreview: some View {
        if let salvage {
            let positiveYields = salvage.yields.filter { $0.quantity > 0 }
            Text(L10n.ui_itemdetailview_you_will_receive_25585)
                .trinketTypography(.secondaryBody)

            if !positiveYields.isEmpty {
                TrinketWalletGrid(columnCount: min(4, positiveYields.count)) {
                    ForEach(positiveYields, id: \.resource) { yield in
                        TrinketWalletResourcePill(
                            title: yield.resource.displayName,
                            amount: yield.quantity,
                            showsIncreasePrefix: true,
                        ) {
                            HomesteadResourceArtwork(resource: yield.resource)
                        }
                    }
                }
            }

            if let equippedByName = salvage.equippedByName {
                Text(L10n.ui_itemdetailview_this_unequips_it_from_1_ae725("\(equippedByName)"))
                    .trinketTypography(.secondaryBody)
            }
        }
    }

    private func confirmSalvage() {
        guard let salvage else { return }
        let result = salvage.onSalvage()
        salvage.onSalvageFinished?(result)
        switch result {
        case .success, .itemNotFound: dismiss()
        case .persistenceFailure: break
        }
    }
}

private extension DetailHeroScrollShell {
    func sizingHero(in size: CGSize, primaryAction: DetailPrimaryAction?) -> Self {
        var shell = self
        // Measure before the fixed action footer reserves space in the scroll view.
        shell.heroContainerSize = size
        shell.primaryAction = primaryAction
        return shell
    }
}
