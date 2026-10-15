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

            GameLabel(item.displayName, balanced: true)
                .trinketTypography(.cardLabel)
                .shineText(shine ?? item.displayTextShine)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .trinketFittedText()

            if showsAffixCount {
                Text(L10n.ui_itemcardlabel_trait_count(item.affixes.count))
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
            labelOverride: item.isTrinket ? String(localized: L10n.ui_itemcardlabel_trinket_ae23c) : nil,
        )
        .trinketFittedText()
        if item.isCorrupted {
            Text(balanced: String(localized: L10n.ui_itemcardlabel_corrupted_a7f0f))
                .trinketTypography(.eyebrow)
                .shineText(.corruption)
                .foregroundStyle(TrinketDesign.Colors.destructive)
                .trinketFittedText()
        }
    }
}
