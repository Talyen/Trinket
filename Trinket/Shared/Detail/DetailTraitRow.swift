import SwiftUI
import TrinketDesignSystem

/// Shared trait container for combatant, item, and ability detail.
struct DetailTraitRow: View {
    var title: String?
    let description: String
    var descriptionAccessibilityID: String?

    init(
        title: String? = nil,
        description: String,
        descriptionAccessibilityID: String? = nil
    ) {
        self.title = title
        self.description = description
        self.descriptionAccessibilityID = descriptionAccessibilityID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            if let title, !title.isEmpty {
                Text(title)
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(.primary)
            }

            descriptionText
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trinketSurface(.secondary)
    }

    @ViewBuilder
    private var descriptionText: some View {
        let text = KeywordDescriptionText(text: description)
            .trinketTypography(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
        if let descriptionAccessibilityID {
            text.accessibilityIdentifier(descriptionAccessibilityID)
        } else {
            text
        }
    }
}
