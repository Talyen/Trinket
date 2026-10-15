import SwiftUI
import TrinketDesignSystem

@MainActor
public struct ViewAllShelfCard: View {
    let remainingCount: Int?
    var accessibilityIdentifier: String?

    public init(
        remainingCount: Int? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.remainingCount = remainingCount
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            Image(systemName: "arrow.right")
                .trinketTypography(.button)
                .foregroundStyle(.primary)
                .frame(width: 48, height: 48)
                .background(TrinketDesign.Colors.surface, in: Circle())
                .accessibilityHidden(true)

            Text(balanced: String(localized: L10n.ui_viewallshelfcard_view_all_ff557))
                .trinketTypography(.caption)
                .foregroundStyle(.secondary)
                .trinketFittedText()
        }
        .frame(width: 88)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(remainingCount.map { $0 > 0 ? String(localized: L10n.ui_viewallshelfcard_1_more_2861b("\($0)")) : "" } ?? "")
        .trinketAccessibilityIdentifier(accessibilityIdentifier)
    }
}
