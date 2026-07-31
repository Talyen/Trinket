import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let item: InventoryItem
    var purchasePrice: Int?
    var canAfford: Bool = true
    var isPurchaseDisabled: Bool = false
    /// When set, replaces the default Buy / Need Gold label (e.g. Sold Out).
    var purchaseButtonTitleOverride: String?
    var onPurchase: (() -> Void)?
    var primaryActionTitle: String?
    var primaryActionAccessibilityID: String?
    var dismissAfterPrimaryAction = false
    var onPrimaryAction: (() -> Void)?
    var salvageYields: [ResourceAmount]?
    var salvageReceivableYields: [ResourceAmount]?
    var equippedByName: String?
    /// Persistence maps its result to this small presentation contract.
    var onSalvage: (() -> Bool?)?
    var onSalvageFinished: ((Bool) -> Void)?

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
        salvageReceivableYields: [ResourceAmount]? = nil,
        equippedByName: String? = nil,
        onSalvage: (() -> Bool?)? = nil,
        onSalvageFinished: ((Bool) -> Void)? = nil
    ) {
        self.item = item
        self.purchasePrice = purchasePrice
        self.canAfford = canAfford
        self.isPurchaseDisabled = isPurchaseDisabled
        self.purchaseButtonTitleOverride = purchaseButtonTitleOverride
        self.onPurchase = onPurchase
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionAccessibilityID = primaryActionAccessibilityID
        self.dismissAfterPrimaryAction = dismissAfterPrimaryAction
        self.onPrimaryAction = onPrimaryAction
        self.salvageYields = salvageYields
        self.salvageReceivableYields = salvageReceivableYields
        self.equippedByName = equippedByName
        self.onSalvage = onSalvage
        self.onSalvageFinished = onSalvageFinished
    }

    private var purchaseButtonTitle: String {
        if let purchaseButtonTitleOverride {
            return purchaseButtonTitleOverride
        }
        guard let purchasePrice else { return "Buy" }
        return canAfford ? "Buy for \(purchasePrice) Gold" : "Need \(purchasePrice) Gold"
    }

    private var showsSalvageAction: Bool {
        salvageYields != nil && onSalvage != nil
            && primaryActionTitle == nil
            && purchasePrice == nil
    }

    public var body: some View {
        DetailHeroScrollShell(
            title: item.displayName,
            header: {
                DetailHeroHeader(
                    eyebrow: item.isCorrupted
                        ? "\(item.rarity.label.uppercased()) · CORRUPTED"
                        : item.rarity.label.uppercased(),
                    title: item.displayName,
                    baseHeight: $0,
                    overscroll: $1
                ) {
                    ItemArtwork(item: item)
                }
                .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemDetail(item.id))
            },
            bodyContent: {
                DetailSection("Traits") {
                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                        ForEach(item.affixes) { affix in
                            DetailTraitRow(description: affix.description)
                        }
                    }
                }

                if let salvageYields, showsSalvageAction {
                    DetailSection("Salvage Value") {
                        ItemSalvageYieldRow(yields: salvageYields)
                    }
                }
            }
        )
        .safeAreaInset(edge: .bottom) {
            if let primaryActionTitle, let onPrimaryAction {
                Button(primaryActionTitle) {
                    onPrimaryAction()
                    if dismissAfterPrimaryAction {
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton(
                    accessibilityIdentifier: primaryActionAccessibilityID ?? primaryActionTitle
                )
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
            } else if purchasePrice != nil, let onPurchase {
                Button {
                    onPurchase()
                } label: {
                    Text(purchaseButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton(
                    tint: canAfford && !isPurchaseDisabled ? Keyword.gold.visualStyle.color : .secondary,
                    accessibilityIdentifier: AccessibilityID.Shop.detailBuyButton
                )
                .disabled(!canAfford || isPurchaseDisabled)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
            } else if showsSalvageAction {
                Button("Salvage") {
                    isSalvageConfirmationPresented = true
                }
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton(
                    tint: TrinketDesign.Colors.destructive,
                    accessibilityIdentifier: AccessibilityID.Collection.salvageButton
                )
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
            }
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

    private var salvageConfirmationMessage: String {
        let receivable = salvageReceivableYields ?? []
        let message = if receivable.isEmpty {
            "You will receive nothing because your materials are full."
        } else {
            "You will receive \(Self.formattedYieldList(receivable))."
        }
        if let equippedByName {
            return message + " This unequips it from \(equippedByName)."
        }
        return message
    }

    private func confirmSalvage() {
        guard let onSalvage else { return }
        switch onSalvage() {
        case true:
            onSalvageFinished?(true)
            dismiss()
        case false:
            onSalvageFinished?(false)
            dismiss()
        case nil:
            salvageErrorMessage = "Couldn't salvage this item. Try again."
        }
    }

    static func formattedYieldList(_ yields: [ResourceAmount]) -> String {
        let parts = yields.map { "\($0.quantity) \($0.resource.displayName)" }
        switch parts.count {
        case 0:
            return "nothing"
        case 1:
            return parts[0]
        case 2:
            return "\(parts[0]) and \(parts[1])"
        default:
            let head = parts.dropLast().joined(separator: ", ")
            return "\(head), and \(parts[parts.count - 1])"
        }
    }
}

struct ItemSalvageYieldRow: View {
    let yields: [ResourceAmount]

    var body: some View {
        HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            ForEach(yields) { amount in
                HStack(spacing: TrinketDesign.Metrics.tightSpacing) {
                    HomesteadResourceArtwork(resource: amount.resource)
                        .frame(width: 24, height: 24)
                    Text("\(amount.quantity) \(amount.resource.displayName)")
                        .trinketTypography(.body)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
    }
}
