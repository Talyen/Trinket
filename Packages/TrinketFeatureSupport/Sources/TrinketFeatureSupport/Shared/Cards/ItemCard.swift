import SwiftUI
import TrinketContent
import TrinketDesignSystem

public struct ItemCard: View {
    let item: InventoryItem
    var showsAffixCount: Bool
    var showsName: Bool = true
    var reservesLabelSpace: Bool = true
    /// When false, art is clipped only — no panel fill/stroke/shadow (shop offer tiles).
    var appliesCardSurface: Bool = true
    var isSelected = false

    public init(
        item: InventoryItem,
        showsAffixCount: Bool,
        showsName: Bool = true,
        reservesLabelSpace: Bool = true,
        appliesCardSurface: Bool = true,
        isSelected: Bool = false
    ) {
        self.item = item
        self.showsAffixCount = showsAffixCount
        self.showsName = showsName
        self.reservesLabelSpace = reservesLabelSpace
        self.appliesCardSurface = appliesCardSurface
        self.isSelected = isSelected
    }

    public var body: some View {
        ProductCardShell(
            isSelected: isSelected,
            appliesCardSurface: appliesCardSurface,
            showsLabel: showsName,
            reservesLabelSpace: reservesLabelSpace,
            art: {
                ItemArtwork(item: item, variant: .thumbnail)
            },
            label: {
                VStack(spacing: TrinketDesign.Metrics.tightSpacing) {
                    HStack(spacing: TrinketDesign.Metrics.tightSpacing) {
                        TrinketRarityLabel(rarity: item.rarity)
                            .lineLimit(1)
                        if item.isCorrupted {
                            Text("Corrupted")
                                .trinketTypography(.caption)
                                .foregroundStyle(TrinketDesign.Colors.destructive)
                                .lineLimit(1)
                        }
                    }

                    Text(item.displayName)
                        .trinketTypography(.cardLabel)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if showsAffixCount {
                        Text(item.affixCountLabel)
                            .trinketTypography(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        )
    }
}

private extension InventoryItem {
    var affixCountLabel: String {
        "\(affixes.count) \(affixes.count == 1 ? "trait" : "traits")"
    }
}
