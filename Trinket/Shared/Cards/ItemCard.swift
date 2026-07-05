import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ItemCard: View {
    let item: InventoryItem
    var showsAffixCount: Bool
    var showsName: Bool = true
    var reservesLabelSpace: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    if let imageName = item.artReference?.imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        TrinketDesign.cardShape
                            .fill(Color(.secondarySystemBackground))
                    }
                }
                .clipShape(TrinketDesign.cardShape)
                .trinketCardSurface()

            if showsName {
                VStack(spacing: 2) {
                    Text(item.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if showsAffixCount {
                        Text(item.affixCountLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 4)
                .trinketCardLabelSpace(reservesLabelSpace)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName), \(item.baseType.slot.rawValue)")
    }
}

private extension InventoryItem {
    var affixCountLabel: String {
        "\(affixes.count) \(affixes.count == 1 ? "affix" : "affixes")"
    }
}
