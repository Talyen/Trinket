import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Reusable item tile for encounter choices (Mystery / Shop).
@MainActor
struct EncounterItemTile: View {
    let item: InventoryItem
    var showsName: Bool = false
    var isDisabled: Bool = false
    var accessibilityID: String?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                ItemCard(
                    item: item,
                    showsAffixCount: false,
                    showsName: false,
                    appliesCardSurface: false
                )

                if showsName {
                    Text(item.displayName)
                        .trinketTypography(.badge)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .trinketQuietTapButtonStyle()
        .disabled(isDisabled)
        .optionalAccessibilityIdentifier(accessibilityID)
    }
}

private extension View {
    @ViewBuilder
    func optionalAccessibilityIdentifier(_ id: String?) -> some View {
        if let id {
            accessibilityIdentifier(id)
        } else {
            self
        }
    }
}
