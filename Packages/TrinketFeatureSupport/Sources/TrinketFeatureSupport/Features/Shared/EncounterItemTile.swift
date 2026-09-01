import SwiftUI
import TrinketContent
import TrinketDesignSystem

@MainActor
public struct EncounterItemTile: View {
    let item: InventoryItem
    var showsName: Bool = false
    var isSelected: Bool = false
    var selectionShineColors: [Color]?
    var isDisabled: Bool = false
    var accessibilityID: String?
    let onSelect: () -> Void

    public init(
        item: InventoryItem,
        showsName: Bool = false,
        isSelected: Bool = false,
        selectionShineColors: [Color]? = nil,
        isDisabled: Bool = false,
        accessibilityID: String? = nil,
        onSelect: @escaping () -> Void,
    ) {
        self.item = item
        self.showsName = showsName
        self.isSelected = isSelected
        self.selectionShineColors = selectionShineColors
        self.isDisabled = isDisabled
        self.accessibilityID = accessibilityID
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(spacing: TrinketDesign.Layout.sectionHeaderSpacing) {
                ItemCard(
                    item: item,
                    showsAffixCount: false,
                    showsName: false,
                    appliesCardSurface: false,
                    isSelected: isSelected,
                    customShineColors: isSelected ? selectionShineColors : nil,
                )

                if showsName {
                    Text(balanced: item.displayName)
                        .trinketTypography(.badge)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .trinketFittedText()
                }
            }
        }
        .trinketQuietTapButtonStyle()
        .disabled(isDisabled)
        .trinketAccessibilityIdentifier(accessibilityID)
    }
}
