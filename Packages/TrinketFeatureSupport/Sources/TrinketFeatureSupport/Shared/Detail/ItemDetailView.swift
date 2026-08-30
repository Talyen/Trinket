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
    private enum Action {
        case none
        case purchase(
            price: Int,
            canAfford: Bool,
            isDisabled: Bool,
            titleOverride: String?,
            accessibilityID: String,
            onPurchase: () -> Void,
        )
        case primaryAction(
            title: String,
            accessibilityID: String?,
            onAction: () -> Void,
        )
        case salvage(
            yields: [ResourceAmount],
            equippedByName: String?,
            onSalvage: () -> ItemSalvageActionResult,
            onSalvageFinished: ((ItemSalvageActionResult) -> Void)?,
        )
    }

    @Environment(\.dismiss) private var dismiss

    let item: InventoryItem
    private let action: Action

    @State private var isSalvageConfirmationPresented = false
    @State private var salvageErrorMessage: String?

    public init(item: InventoryItem) {
        self.item = item
        action = .none
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
        action = .purchase(
            price: purchasePrice,
            canAfford: canAfford,
            isDisabled: isPurchaseDisabled,
            titleOverride: purchaseButtonTitleOverride,
            accessibilityID: accessibilityIdentifier,
            onPurchase: onPurchase,
        )
    }

    public init(
        item: InventoryItem,
        primaryActionTitle: String,
        primaryActionAccessibilityID: String? = nil,
        onPrimaryAction: @escaping () -> Void,
    ) {
        self.item = item
        action = .primaryAction(
            title: primaryActionTitle,
            accessibilityID: primaryActionAccessibilityID,
            onAction: onPrimaryAction,
        )
    }

    public init(
        item: InventoryItem,
        salvageYields: [ResourceAmount],
        equippedByName: String? = nil,
        onSalvage: @escaping () -> ItemSalvageActionResult,
        onSalvageFinished: ((ItemSalvageActionResult) -> Void)? = nil,
    ) {
        self.item = item
        action = .salvage(
            yields: salvageYields,
            equippedByName: equippedByName,
            onSalvage: onSalvage,
            onSalvageFinished: onSalvageFinished,
        )
    }

    private var showsSalvageAction: Bool {
        guard case .salvage = action else { return false }
        return !item.isTrinket && item.rarity != .unique
    }

    public var body: some View {
        DetailHeroScrollShell(
            title: item.displayName,
            header: {
                DetailHeroHeader(
                    eyebrow: ItemDetailContent.eyebrow(for: item),
                    title: item.displayName,
                    titleKeywords: Set(item.astralShineKeywords ?? []),
                    titleShineColors: item.rarity == .unique ? UniqueShine.textColors : nil,
                    baseHeight: $0,
                    overscroll: $1,
                ) {
                    ItemArtwork(item: item)
                }
                .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemDetail(item.id))
            },
            bodyContent: {
                ItemDetailContent(
                    item: item,
                    showsSalvageAction: showsSalvageAction,
                    onSalvageTapped: { isSalvageConfirmationPresented = true },
                )
            },
        )
        .safeAreaInset(edge: .bottom) {
            footerView
        }
        .alert(
            "Salvage \(item.displayName)?",
            isPresented: $isSalvageConfirmationPresented,
        ) {
            Button("Salvage", role: .destructive) {
                confirmSalvage()
            }
            .accessibilityIdentifier(AccessibilityID.Collection.salvageConfirmButton)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(salvageConfirmationMessage)
        }
        .alert(
            "Salvage Failed",
            isPresented: Binding(
                get: { salvageErrorMessage != nil },
                set: {
                    if !$0 {
                        salvageErrorMessage = nil
                    }
                },
            ),
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(salvageErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var footerView: some View {
        switch action {
        case .none, .salvage:
            EmptyView()
        case let .primaryAction(title, accessibilityID, onAction):
            DetailPrimaryActionFooter(
                title: title,
                accessibilityIdentifier: accessibilityID,
                action: onAction,
            )
        case let .purchase(price, canAfford, isDisabled, titleOverride, accessibilityID, onPurchase):
            DetailPrimaryActionFooter(
                title: purchaseButtonTitle(price: price, canAfford: canAfford, titleOverride: titleOverride),
                accessibilityIdentifier: accessibilityID,
                isDisabled: !canAfford || isDisabled,
                action: onPurchase,
            )
        }
    }

    private func purchaseButtonTitle(
        price: Int,
        canAfford: Bool,
        titleOverride: String?,
    ) -> String {
        if let titleOverride {
            return titleOverride
        }
        return canAfford ? "Buy for \(price) Gold" : "Need \(price) Gold"
    }

    private var salvageConfirmationMessage: String {
        guard case let .salvage(yields, equippedByName, _, _) = action else { return "" }
        let message = "You will receive \(yields.formattedYieldList)."
        if let equippedByName {
            return message + " This unequips it from \(equippedByName)."
        }
        return message
    }

    private func confirmSalvage() {
        guard case let .salvage(_, _, onSalvage, onSalvageFinished) = action else { return }
        switch onSalvage() {
        case let .success(yields):
            onSalvageFinished?(.success(yields: yields))
            dismiss()
        case .itemNotFound:
            onSalvageFinished?(.itemNotFound)
            dismiss()
        case .persistenceFailure:
            salvageErrorMessage = "Couldn't salvage this item. Try again."
        }
    }
}

struct ItemDetailContent: View {
    let item: InventoryItem
    let showsSalvageAction: Bool
    let onSalvageTapped: () -> Void

    static func eyebrow(for item: InventoryItem) -> String {
        let tag = item.isTrinket ? "TRINKET" : item.rarity.label.uppercased()
        return item.isCorrupted ? "\(tag) · CORRUPTED" : tag
    }

    private func uniqueAffixShineColors(_ affix: ItemAffix) -> [Color]? {
        if item.rarity == .unique {
            return UniqueShine.textColors
        }
        return affix.isCorrupted ? CorruptionShine.textColors : nil
    }

    var body: some View {
        DetailSection("Traits") {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                ForEach(Array(item.displayedAffixes.enumerated()), id: \.element.id) { index, affix in
                    DetailTraitRow(
                        title: affix.title,
                        description: affix.description,
                        titleKeywords: item.isPerfectAffix(at: index) ? affix.keywords : [],
                        titleShineColors: uniqueAffixShineColors(affix),
                    )
                }
            }
        }

        if showsSalvageAction {
            Button("Salvage") {
                onSalvageTapped()
            }
            .frame(maxWidth: .infinity)
            .trinketSecondaryActionButton(
                tint: TrinketDesign.Colors.destructive,
                accessibilityIdentifier: AccessibilityID.Collection.salvageButton,
            )
            .padding(.top, TrinketDesign.Metrics.sectionSpacing)
        }
    }
}
