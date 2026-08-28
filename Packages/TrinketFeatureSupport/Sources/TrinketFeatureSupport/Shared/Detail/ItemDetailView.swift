import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public enum ItemSalvageActionResult: Equatable, Sendable {
    case success(yields: [ResourceAmount])
    case itemNotFound
    case persistenceFailure
}

public enum ItemDetailFooter: Equatable {
    case none
    case purchase(
        price: Int,
        canAfford: Bool,
        isDisabled: Bool,
        titleOverride: String?,
        accessibilityID: String
    )
    case primaryAction(
        title: String,
        accessibilityID: String?,
        dismissAfter: Bool
    )
}

public struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let item: InventoryItem
    let footer: ItemDetailFooter
    var salvageYields: [ResourceAmount]?
    var equippedByName: String?
    var onPurchase: (() -> Void)?
    var onPrimaryAction: (() -> Void)?
    var onSalvage: (() -> ItemSalvageActionResult)?
    var onSalvageFinished: ((ItemSalvageActionResult) -> Void)?

    @State private var isSalvageConfirmationPresented = false
    @State private var salvageErrorMessage: String?

    public init(
        item: InventoryItem,
        purchasePrice: Int? = nil,
        canAfford: Bool = true,
        isPurchaseDisabled: Bool = false,
        purchaseButtonTitleOverride: String? = nil,
        onPurchase: (() -> Void)? = nil,
        primaryActionTitle: String? = nil,
        primaryActionAccessibilityID: String? = nil,
        dismissAfterPrimaryAction: Bool = false,
        onPrimaryAction: (() -> Void)? = nil,
        salvageYields: [ResourceAmount]? = nil,
        equippedByName: String? = nil,
        onSalvage: (() -> ItemSalvageActionResult)? = nil,
        onSalvageFinished: ((ItemSalvageActionResult) -> Void)? = nil
    ) {
        self.item = item
        self.salvageYields = salvageYields
        self.equippedByName = equippedByName
        self.onPurchase = onPurchase
        self.onPrimaryAction = onPrimaryAction
        self.onSalvage = onSalvage
        self.onSalvageFinished = onSalvageFinished

        if let primaryActionTitle, onPrimaryAction != nil {
            footer = .primaryAction(
                title: primaryActionTitle,
                accessibilityID: primaryActionAccessibilityID,
                dismissAfter: dismissAfterPrimaryAction
            )
        } else if let purchasePrice, onPurchase != nil {
            footer = .purchase(
                price: purchasePrice,
                canAfford: canAfford,
                isDisabled: isPurchaseDisabled,
                titleOverride: purchaseButtonTitleOverride,
                accessibilityID: AccessibilityID.Shop.detailBuyButton
            )
        } else {
            footer = .none
        }
    }

    private var showsSalvageAction: Bool {
        !item.isTrinket
            && item.rarity != .unique
            && onSalvage != nil
            && footer == .none
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
                    overscroll: $1
                ) {
                    ItemArtwork(item: item)
                }
                .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemDetail(item.id))
            },
            bodyContent: {
                ItemDetailContent(
                    item: item,
                    showsSalvageAction: showsSalvageAction,
                    onSalvageTapped: { isSalvageConfirmationPresented = true }
                )
            }
        )
        .safeAreaInset(edge: .bottom) {
            footerView
        }
        .alert(
            "Salvage \(item.displayName)?",
            isPresented: $isSalvageConfirmationPresented
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
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(salvageErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var footerView: some View {
        switch footer {
        case .none:
            EmptyView()
        case let .primaryAction(title, accessibilityID, dismissAfter):
            if let onPrimaryAction {
                Button(title) {
                    onPrimaryAction()
                    if dismissAfter {
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton(
                    accessibilityIdentifier: accessibilityID ?? title
                )
                .trinketCenteredPrimaryAction()
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
                .trinketSheetChromeIgnoresDismissDrag()
            }
        case let .purchase(price, canAfford, isDisabled, titleOverride, accessibilityID):
            if let onPurchase {
                Button {
                    onPurchase()
                } label: {
                    Text(purchaseButtonTitle(
                        price: price,
                        canAfford: canAfford,
                        titleOverride: titleOverride
                    ))
                    .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton(accessibilityIdentifier: accessibilityID)
                .trinketCenteredPrimaryAction()
                .disabled(!canAfford || isDisabled)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
                .trinketSheetChromeIgnoresDismissDrag()
            }
        }
    }

    private func purchaseButtonTitle(
        price: Int,
        canAfford: Bool,
        titleOverride: String?
    ) -> String {
        if let titleOverride {
            return titleOverride
        }
        return canAfford ? "Buy for \(price) Gold" : "Need \(price) Gold"
    }

    private var salvageConfirmationMessage: String {
        let message = "You will receive \((salvageYields ?? []).formattedYieldList)."
        if let equippedByName {
            return message + " This unequips it from \(equippedByName)."
        }
        return message
    }

    private func confirmSalvage() {
        guard let onSalvage else { return }
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

    public static func formattedYieldList(_ yields: [ResourceAmount]) -> String {
        yields.formattedYieldList
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
                        titleShineColors: uniqueAffixShineColors(affix)
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
                accessibilityIdentifier: AccessibilityID.Collection.salvageButton
            )
            .padding(.top, TrinketDesign.Metrics.sectionSpacing)
        }
    }
}
