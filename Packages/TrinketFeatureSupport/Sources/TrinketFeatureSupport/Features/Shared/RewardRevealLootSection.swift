import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

/// Shared item pager + wallet reveal for victory / mystery reward screens.
public struct RewardRevealLootSection: View {
    let items: [InventoryItem]
    let gold: Int
    let materials: [ResourceAmount]
    let showsIncreasePrefix: Bool
    let emptyMessage: String?
    let itemAccessibilityID: (String) -> String
    let areItemsVisible: Bool
    let visibleWalletRewardCount: Int
    let walletColumnCount: Int
    var spacing: CGFloat = TrinketDesign.Metrics.largeSpacing
    let onSelectItem: (InventoryItem) -> Void

    public static func walletRewardCount(gold: Int, materials: [ResourceAmount]) -> Int {
        (gold > 0 ? 1 : 0) + materials.count { $0.quantity > 0 }
    }

    public init(
        items: [InventoryItem],
        gold: Int,
        materials: [ResourceAmount],
        showsIncreasePrefix: Bool,
        emptyMessage: String?,
        itemAccessibilityID: @escaping (String) -> String,
        areItemsVisible: Bool,
        visibleWalletRewardCount: Int,
        walletColumnCount: Int,
        spacing: CGFloat = TrinketDesign.Metrics.largeSpacing,
        onSelectItem: @escaping (InventoryItem) -> Void
    ) {
        self.items = items
        self.gold = gold
        self.materials = materials
        self.showsIncreasePrefix = showsIncreasePrefix
        self.emptyMessage = emptyMessage
        self.itemAccessibilityID = itemAccessibilityID
        self.areItemsVisible = areItemsVisible
        self.visibleWalletRewardCount = visibleWalletRewardCount
        self.walletColumnCount = walletColumnCount
        self.spacing = spacing
        self.onSelectItem = onSelectItem
    }

    public var body: some View {
        VStack(spacing: spacing) {
            if !items.isEmpty {
                rewardItemPager
                    .opacity(areItemsVisible ? 1 : 0)
                    .scaleEffect(areItemsVisible ? 1 : 0.98)
                    .allowsHitTesting(areItemsVisible)
            }

            rewardWallet
        }
    }

    private var rewardItemPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: TrinketDesign.Metrics.largeSpacing) {
                ForEach(items) { item in
                    Button {
                        onSelectItem(item)
                    } label: {
                        RewardItemRevealCard(item: item)
                    }
                    .trinketQuietTapButtonStyle()
                    .containerRelativeFrame(.horizontal)
                    .accessibilityIdentifier(itemAccessibilityID(item.id))
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
    }

    @ViewBuilder
    private var rewardWallet: some View {
        let positiveMaterials = materials.filter { $0.quantity > 0 }
        let rewardCount = (gold > 0 ? 1 : 0) + positiveMaterials.count

        if rewardCount > 0 {
            let goldOffset = gold > 0 ? 1 : 0
            TrinketWalletGrid(
                columnCount: max(1, min(walletColumnCount, rewardCount))
            ) {
                if gold > 0 {
                    TrinketWalletResourcePill(
                        title: "Gold",
                        amount: gold,
                        showsIncreasePrefix: showsIncreasePrefix
                    ) {
                        HomesteadResourceArtwork(resource: .gold)
                    }
                }

                ForEach(Array(positiveMaterials.enumerated()), id: \.offset) { index, reward in
                    let revealIndex = index + goldOffset
                    TrinketWalletResourcePill(
                        title: reward.resource.displayName,
                        amount: reward.quantity,
                        showsIncreasePrefix: showsIncreasePrefix
                    ) {
                        HomesteadResourceArtwork(resource: reward.resource)
                    }
                    .opacity(revealIndex == 0 || visibleWalletRewardCount > revealIndex ? 1 : 0)
                }
            }
            .opacity(visibleWalletRewardCount > 0 ? 1 : 0)
        } else if items.isEmpty, let emptyMessage {
            Text(balanced: emptyMessage)
                .trinketTypography(.secondaryBody)
                .foregroundStyle(.secondary)
                .opacity(areItemsVisible ? 1 : 0)
        }
    }
}
