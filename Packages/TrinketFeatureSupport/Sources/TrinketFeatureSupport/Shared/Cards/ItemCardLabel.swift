import SwiftUI
import TrinketContent
import TrinketDesignSystem

public struct ItemCardLabel: View {
    let item: InventoryItem
    let showsAffixCount: Bool
    let shine: Shine?

    public init(item: InventoryItem, showsAffixCount: Bool = false, shine: Shine? = nil) {
        self.item = item
        self.showsAffixCount = showsAffixCount
        self.shine = shine
    }

    public var body: some View {
        VStack(spacing: TrinketDesign.Spacing.tight) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TrinketDesign.Spacing.tight) {
                    statusLabels
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(spacing: TrinketDesign.Spacing.tight) {
                    statusLabels
                }
                .multilineTextAlignment(.center)
            }

            Text(balanced: item.displayName)
                .trinketTypography(.cardLabel)
                .shineText(shine ?? item.displayTextShine)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .trinketFittedText()

            if showsAffixCount {
                Text(balanced: item.affixCountLabel)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                    .trinketFittedText()
            }
        }
    }

    @ViewBuilder
    private var statusLabels: some View {
        TrinketRarityLabel(
            rarity: item.rarity,
            labelOverride: item.isTrinket ? "Trinket" : nil,
        )
        .trinketFittedText()
        if item.isCorrupted {
            Text(balanced: "CORRUPTED")
                .trinketTypography(.eyebrow)
                .shineText(.corruption)
                .foregroundStyle(TrinketDesign.Colors.destructive)
                .trinketFittedText()
        }
    }
}

private extension InventoryItem {
    var affixCountLabel: String {
        "\(affixes.count) \(affixes.count == 1 ? "trait" : "traits")"
    }
}
