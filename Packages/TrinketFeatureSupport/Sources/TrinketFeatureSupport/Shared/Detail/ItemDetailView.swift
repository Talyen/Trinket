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
    var equippedByName: String?
    /// Persistence maps its result to this small presentation contract.
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
        !item.isTrinket
            && item.rarity != .unique
            && onSalvage != nil
            && primaryActionTitle == nil
            && purchasePrice == nil
    }

    /// Every affix on a Unique carries the ember shine; corruption cannot coexist.
    private func uniqueAffixShineColors(_ affix: ItemAffix) -> [Color]? {
        if item.rarity == .unique {
            return UniqueShine.textColors
        }
        return affix.isCorrupted ? CorruptionShine.textColors : nil
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
                    titleKeywords: item.rarity == .astral ? item.baseType.keywordAffinities : [],
                    titleShineColors: item.rarity == .unique ? UniqueShine.textColors : nil,
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
                        isSalvageConfirmationPresented = true
                    }
                    .frame(maxWidth: .infinity)
                    .trinketSecondaryActionButton(
                        tint: TrinketDesign.Colors.destructive,
                        accessibilityIdentifier: AccessibilityID.Collection.salvageButton
                    )
                    .padding(.top, TrinketDesign.Metrics.sectionSpacing)
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
                .trinketCenteredPrimaryAction()
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
                .trinketSheetChromeIgnoresDismissDrag()
            } else if purchasePrice != nil, let onPurchase {
                Button {
                    onPurchase()
                } label: {
                    Text(purchaseButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton(
                    accessibilityIdentifier: AccessibilityID.Shop.detailBuyButton
                )
                .trinketCenteredPrimaryAction()
                .disabled(!canAfford || isPurchaseDisabled)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
                .trinketSheetChromeIgnoresDismissDrag()
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
        let message = "You will receive \(Self.formattedYieldList(salvageYields ?? []))."
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
