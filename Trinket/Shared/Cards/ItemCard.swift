import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ItemCard: View {
    let item: InventoryItem
    var showsAffixCount: Bool
    var showsName: Bool = true
    var reservesLabelSpace: Bool = true
    /// When false, art is clipped only — no panel fill/stroke/shadow (shop offer tiles).
    var appliesCardSurface: Bool = true
    var isSelected = false

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            artTile

            if showsName {
                VStack(spacing: 2) {
                    TrinketRarityLabel(rarity: item.rarity)
                        .lineLimit(1)

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
                .padding(.horizontal, TrinketDesign.Metrics.extraSmallSpacing)
                .trinketCardLabelSpace(reservesLabelSpace)
            }
        }
    }

    @ViewBuilder
    private var artTile: some View {
        let tile = TrinketDesign.cardShape
            .fill(TrinketDesign.Colors.surface)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                ItemArtwork(item: item, variant: .thumbnail)
                    .clipShape(TrinketDesign.cardShape)
            }

        if appliesCardSurface {
            tile
                .trinketCardSurface()
                .trinketArtworkPickerSelectionBorder(
                    isSelected: isSelected,
                    lineWidth: 1.5
                )
        } else {
            tile
                .clipShape(TrinketDesign.cardShape)
                .trinketArtworkPickerSelectionBorder(
                    isSelected: isSelected,
                    lineWidth: 1.5
                )
        }
    }
}

private extension InventoryItem {
    var affixCountLabel: String {
        "\(affixes.count) \(affixes.count == 1 ? "trait" : "traits")"
    }
}
