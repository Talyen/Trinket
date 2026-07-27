import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

enum InventoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case weapon = "Weapon"
    case armor = "Armor"
    case trinket = "Trinket"

    var id: String {
        rawValue
    }

    var slot: ItemSlot? {
        switch self {
        case .all:
            nil
        case .weapon:
            .weapon
        case .armor:
            .armor
        case .trinket:
            .trinket
        }
    }
}

struct InventoryGridView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedFilter: InventoryFilter = .all
    @State private var selectedItem: InventoryItem?
    @State private var salvageSuccessCount = 0
    @Namespace private var zoomNamespace

    var body: some View {
        let inventoryState = appState.inventory
        let items = filteredItems(from: inventoryState)

        CollectionGridShell(items: items) { item in
            Button {
                selectedItem = item
            } label: {
                ItemCard(
                    item: item,
                    showsAffixCount: false
                )
            }
            .trinketQuietTapButtonStyle()
            .matchedTransitionSource(id: item.id, in: zoomNamespace)
            .accessibilityIdentifier("\(item.displayName) item card")
        } emptyView: {
            inventoryEmptyState(inventoryState: inventoryState)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(InventoryFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .trinketTypography(selectedFilter != .all ? .button : .body)
                        .foregroundStyle(selectedFilter != .all ? TrinketDesign.Colors.cardArtAccent : .primary)
                }

                .accessibilityIdentifier("Inventory filter")
            }
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailView.inventorySalvageDetail(item: item, appState: appState) { didSucceed in
                    if didSucceed {
                        salvageSuccessCount += 1
                    }
                    selectedItem = nil
                }
            }
            .navigationTransition(.zoom(sourceID: item.id, in: zoomNamespace))
            .trinketDetailSheet()
        }
        .trinketSensoryFeedback(
            .success,
            trigger: salvageSuccessCount,
            enabled: appState.options.hapticsEnabled
        )
    }

    private func filteredItems(from inventoryState: PlayerInventoryState) -> [InventoryItem] {
        inventoryState.items.filter { item in
            selectedFilter.slot.map { $0 == item.baseType.slot } ?? true
        }
    }

    @ViewBuilder
    private func inventoryEmptyState(inventoryState: PlayerInventoryState) -> some View {
        let isFilteredEmpty = !inventoryState.items.isEmpty

        if isFilteredEmpty {
            ContentUnavailableView(
                "No Matching Items",
                systemImage: "line.3.horizontal.decrease",
                description: Text("Try a different filter.")
            )
            .accessibilityIdentifier(AccessibilityID.Collection.inventoryNoResults)
        } else {
            ContentUnavailableView(
                "No Items Yet",
                systemImage: "shippingbox",
                description: Text("Complete stages to earn gear for your heroes.")
            )
            .accessibilityIdentifier(AccessibilityID.Collection.inventoryEmptyState)
        }
    }
}

struct ItemDetailView: View {
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
    var onSalvage: (() -> ItemSalvageResult?)?
    var onSalvageFinished: ((Bool) -> Void)?

    @State private var isSalvageConfirmationPresented = false
    @State private var salvageErrorMessage: String?

    init(
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
        onSalvage: (() -> ItemSalvageResult?)? = nil,
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

    var body: some View {
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
        case .success:
            onSalvageFinished?(true)
            dismiss()
        case .itemNotFound:
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

    /// Collection inventory detail with salvage affordances for owned items.
    @MainActor
    static func inventorySalvageDetail(
        item: InventoryItem,
        appState: AppState,
        onFinished: @escaping (_ didSucceed: Bool) -> Void
    ) -> ItemDetailView {
        let isOwned = appState.inventory.items.contains { $0.id == item.id }
        guard isOwned else {
            return ItemDetailView(item: item)
        }
        let yields = ItemSalvage.yields(for: item)
        return ItemDetailView(
            item: item,
            salvageYields: yields,
            salvageReceivableYields: appState.homestead.receivableAmounts(from: yields),
            equippedByName: appState.equippedCombatantName(for: item.id),
            onSalvage: { appState.salvageItem(id: item.id) },
            onSalvageFinished: onFinished
        )
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
