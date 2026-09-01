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
        ProductCardShell(
            appliesCardSurface: true,
            showsLabel: false,
            reservesLabelSpace: false,
            accessibilityID: accessibilityIdentifier,
        ) {
            VStack(spacing: TrinketDesign.Spacing.small) {
                Image(systemName: "square.grid.2x2.fill")
                    // UIStyleCheck: allow - SF Symbol glyph sizing, not copy
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(TrinketDesign.Colors.accent)
                    .accessibilityHidden(true)

                Text(balanced: "View All")
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(.primary)
                    .trinketFittedText()

                if let remainingCount, remainingCount > 0 {
                    Text(balanced: "+\(remainingCount) more")
                        .trinketTypography(.footnote)
                        .foregroundStyle(.secondary)
                        .trinketFittedText()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .collectionShelfCardWidth()
    }
}
