import SwiftUI

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
                    TrinketDesign.cardShape
                        .fill(TrinketDesign.CardPlaceholderStyle.item.color.opacity(0.18))
                }
                .overlay {
                    Image(systemName: TrinketDesign.CardPlaceholderStyle.item.symbolName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(TrinketDesign.CardPlaceholderStyle.item.color)
                        .accessibilityHidden(true)
                }
                .trinketCardSurface()

            if showsName {
                Text(item.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .reservedCardLabelSpace(reservesLabelSpace)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName), \(item.baseType.slot.rawValue)")
    }
}

private extension View {
    @ViewBuilder
    func reservedCardLabelSpace(_ isReserved: Bool) -> some View {
        if isReserved {
            frame(minHeight: TrinketDesign.Metrics.cardLabelReservedHeight, alignment: .center)
        } else {
            self
        }
    }
}
