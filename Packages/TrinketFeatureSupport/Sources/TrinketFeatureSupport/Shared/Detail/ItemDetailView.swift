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
                ?? (canAfford ? "Buy for \(purchasePrice) Gold" : "Need \(purchasePrice) Gold"),
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
        DetailHeroScrollShell(
            title: item.displayName,
            header: { baseHeight in
                DetailHeroHeader(
                    eyebrow: Self.eyebrow(for: item),
                    title: item.displayName,
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
        .safeAreaInset(edge: .bottom) {
            if let primaryAction {
                DetailPrimaryActionFooter(primaryAction: primaryAction)
            }
        }
    }

    private static func eyebrow(for item: InventoryItem) -> String {
        let tag = item.isTrinket ? "TRINKET" : item.rarity.label.uppercased()
        return item.isCorrupted ? "\(tag) · CORRUPTED" : tag
    }

    @ViewBuilder
    private var traitsSection: some View {
        DetailSection("Traits") {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                ForEach(Array(item.displayedAffixes.enumerated()), id: \.element.id) { index, affix in
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
                    Text(salvageConfirmationMessage)
                        .trinketTypography(.secondaryBody)
                    Button("Cancel") { isSalvageConfirmationPresented = false }
                        .trinketSecondaryActionButton(accessibilityIdentifier: AccessibilityID.Collection.salvageCancelButton)
                    Button("Salvage", role: .destructive) {
                        guard isSalvageConfirmationPresented else { return }
                        isSalvageConfirmationPresented = false
                        confirmSalvage()
                    }
                    .trinketPrimaryActionButton(
                        tint: TrinketDesign.Colors.destructive,
                        accessibilityIdentifier: AccessibilityID.Collection.salvageConfirmButton,
                    )
                } else {
                    Button("Salvage") { isSalvageConfirmationPresented = true }
                        .trinketSecondaryActionButton(
                            tint: TrinketDesign.Colors.destructive,
                            accessibilityIdentifier: AccessibilityID.Collection.salvageButton,
                        )
                }
            }
            .padding(.top, TrinketDesign.Layout.sectionSpacing)
        }
    }

    private var salvageConfirmationMessage: String {
        guard let salvage else { return "" }
        let message = "You will receive \(salvage.yields.formattedYieldList)."
        if let equippedByName = salvage.equippedByName {
            return message + " This unequips it from \(equippedByName)."
        }
        return message
    }

    private func confirmSalvage() {
        guard let salvage else { return }
        switch salvage.onSalvage() {
        case let .success(yields):
            salvage.onSalvageFinished?(.success(yields: yields))
            dismiss()
        case .itemNotFound:
            salvage.onSalvageFinished?(.itemNotFound)
            dismiss()
        case .persistenceFailure:
            salvage.onSalvageFinished?(.persistenceFailure)
        }
    }
}
