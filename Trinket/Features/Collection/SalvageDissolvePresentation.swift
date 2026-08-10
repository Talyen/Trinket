import SwiftUI
import TrinketBattleFeature
import TrinketContent
import TrinketFeatureSupport

/// Snapshot of an item kept visible after salvage until dissolve finishes.
struct SalvageDissolveTombstone: Equatable {
    let item: InventoryItem
    let index: Int
}

enum SalvageDissolvePresentation {
    /// Re-inserts a salvaged item at its prior index so the cell can dissolve in place.
    static func displayedItems(
        _ items: [InventoryItem],
        tombstone: SalvageDissolveTombstone?
    ) -> [InventoryItem] {
        guard let tombstone else { return items }
        guard !items.contains(where: { $0.id == tombstone.item.id }) else { return items }
        var result = items
        let index = min(max(0, tombstone.index), result.count)
        result.insert(tombstone.item, at: index)
        return result
    }
}

/// Item card that optionally plays the battle dissolve clip before the parent collapses layout.
struct SalvageAwareItemCard: View {
    let item: InventoryItem
    var showsAffixCount: Bool
    var showsName: Bool = true
    var isDissolving: Bool
    var onDissolveFinished: (() -> Void)?

    var body: some View {
        if isDissolving {
            ItemCard(
                item: item,
                showsAffixCount: showsAffixCount,
                showsName: showsName,
                fadesLabel: true
            ) {
                BattleDissolveArtwork(
                    celebratesDefeat: false,
                    onFinished: onDissolveFinished
                ) {
                    ItemArtwork(item: item, variant: .thumbnail)
                }
            }
        } else {
            ItemCard(
                item: item,
                showsAffixCount: showsAffixCount,
                showsName: showsName
            )
        }
    }
}
