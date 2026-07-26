import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

/// Shared item pager + wallet reveal for victory / mystery reward screens.
struct RewardRevealLootSection: View {
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

    var body: some View {
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
            TrinketWalletGrid(columnCount: max(1, min(walletColumnCount, rewardCount))) {
                if gold > 0 {
                    TrinketWalletResourcePill(
                        title: "Gold",
                        amount: gold,
                        showsIncreasePrefix: showsIncreasePrefix
                    ) {
                        HomesteadResourceArtwork(resource: .gold)
                    }
                }

                ForEach(Array(positiveMaterials.enumerated()), id: \.element.resource) { index, reward in
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
            Text(emptyMessage)
                .trinketTypography(.secondaryBody)
                .foregroundStyle(.secondary)
                .opacity(areItemsVisible ? 1 : 0)
        }
    }
}
