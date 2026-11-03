import SwiftUI
import TrinketContent
import TrinketDesignSystem

public struct EquippedItemBadge: View {
    @Environment(\.locale) private var locale
    let wearerName: String

    public init(wearerName: String) {
        self.wearerName = wearerName
    }

    public var body: some View {
        Image(systemName: "person.fill")
            .trinketTypography(.badge)
            .foregroundStyle(.primary)
            .frame(width: 24, height: 24)
            .background(TrinketDesign.Colors.panel, in: Circle())
            .padding(TrinketDesign.Spacing.tight)
            .accessibilityLabel(String(localized: L10n.ui_itemslotpickerview_equipped_by_1_a51ee(
                ContentCopy.localized(wearerName, locale: locale),
            )))
            .allowsHitTesting(false)
    }
}
