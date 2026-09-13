import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public struct RewardRevealLootSection: View {
    let items: [InventoryItem]
    let gold: Int
    let materials: [ResourceAmount]
    let showsIncreasePrefix: Bool
    let emptyMessage: String?
    let itemAccessibilityID: (String) -> String
    let areItemsVisible: Bool
    let visibleWalletRewardCount: Int
    let isCollected: Bool
    let hasGathered: Bool
    var spacing: CGFloat = TrinketDesign.Spacing.large
    let onSelectItem: (InventoryItem) -> Void
    @Binding var focusedItemID: String?

    public static func walletRewardCount(gold: Int, materials: [ResourceAmount]) -> Int {
        (gold != 0 ? 1 : 0) + materials.count { $0.quantity > 0 }
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
        spacing: CGFloat = TrinketDesign.Spacing.large,
        isCollected: Bool = false,
        hasGathered: Bool = false,
        focusedItemID: Binding<String?>,
        onSelectItem: @escaping (InventoryItem) -> Void,
    ) {
        self.items = items
        self.gold = gold
        self.materials = materials
        self.showsIncreasePrefix = showsIncreasePrefix
        self.emptyMessage = emptyMessage
        self.itemAccessibilityID = itemAccessibilityID
        self.areItemsVisible = areItemsVisible
        self.visibleWalletRewardCount = visibleWalletRewardCount
        self.spacing = spacing
        self.isCollected = isCollected
        self.hasGathered = hasGathered
        _focusedItemID = focusedItemID
        self.onSelectItem = onSelectItem
    }

    public var body: some View {
        VStack(spacing: spacing) {
            if !items.isEmpty {
                rewardItemPager
                    .trinketPresentationVisibility(areItemsVisible)
                    .scaleEffect(areItemsVisible ? 1 : 0.98)
                    .modifier(RewardGatherModifier(isCollected: isCollected, hasGathered: hasGathered, delay: 0))
            }

            rewardWallet
                .modifier(RewardGatherModifier(
                    isCollected: isCollected, hasGathered: hasGathered,
                    delay: TrinketMotion.Reward.collectionWalletDelay,
                ))
        }
    }

    private var rewardItemPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: TrinketDesign.Spacing.large) {
                ForEach(items) { item in
                    Button {
                        onSelectItem(item)
                    } label: {
                        RewardItemRevealCard(item: item)
                    }
                    .trinketQuietTapButtonStyle()
                    .containerRelativeFrame(.horizontal)
                    .id(item.id)
                    .accessibilityIdentifier(itemAccessibilityID(item.id))
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $focusedItemID)
    }

    @ViewBuilder
    private var rewardWallet: some View {
        let positiveMaterials = materials.filter { $0.quantity > 0 }
        let rewardCount = Self.walletRewardCount(gold: gold, materials: materials)

        if rewardCount > 0 {
            let goldOffset = gold != 0 ? 1 : 0
            TrinketWalletGrid(
                columnCount: min(4, max(1, rewardCount)),
            ) {
                if gold != 0 {
                    TrinketWalletResourcePill(
                        title: "Gold",
                        amount: gold,
                        showsIncreasePrefix: showsIncreasePrefix && gold > 0,
                    ) {
                        HomesteadResourceArtwork(resource: .gold)
                    }
                }

                ForEach(Array(positiveMaterials.enumerated()), id: \.element.resource) { index, reward in
                    let revealIndex = index + goldOffset
                    TrinketWalletResourcePill(
                        title: reward.resource.displayName,
                        amount: reward.quantity,
                        showsIncreasePrefix: showsIncreasePrefix,
                    ) {
                        HomesteadResourceArtwork(resource: reward.resource)
                    }
                    .trinketPresentationVisibility(revealIndex == 0 || visibleWalletRewardCount > revealIndex)
                }
            }
            .trinketPresentationVisibility(visibleWalletRewardCount > 0)
        } else if items.isEmpty, let emptyMessage {
            Text(balanced: emptyMessage)
                .trinketTypography(.secondaryBody)
                .foregroundStyle(.secondary)
                .trinketPresentationVisibility(areItemsVisible)
        }
    }
}

private struct RewardGatherModifier: ViewModifier {
    let isCollected: Bool
    let hasGathered: Bool
    let delay: TimeInterval

    func body(content: Content) -> some View {
        content
            .scaleEffect(hasGathered ? TrinketMotion.Reward.collectionGatherScale : isCollected ? TrinketMotion.Reward
                .collectionLiftScale : 1)
            .offset(y: hasGathered ? TrinketMotion.Reward.collectionGatherOffset : isCollected ? TrinketMotion.Reward
                .collectionLiftOffset : 0)
            .opacity(hasGathered ? 0 : 1)
            .animation(
                hasGathered ? TrinketMotion.Reward.collectionGather.delay(delay) : TrinketMotion.Reward.collectionLift,
                value: isCollected && !hasGathered,
            )
            .allowsHitTesting(!isCollected)
            .accessibilityHidden(isCollected)
    }
}
