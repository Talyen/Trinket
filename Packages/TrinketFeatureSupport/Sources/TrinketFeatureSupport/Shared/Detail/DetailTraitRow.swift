import SwiftUI
import TrinketCore
import TrinketDesignSystem

/// Shared trait container for combatant, item, and ability detail.
public struct DetailTraitRow: View {
    var title: String?
    let description: String
    var descriptionAccessibilityID: String?
    var leadingIconKeyword: Keyword?
    var titleKeywords: Set<Keyword>

    public init(
        title: String? = nil,
        description: String,
        descriptionAccessibilityID: String? = nil,
        leadingIconKeyword: Keyword? = nil,
        titleKeywords: Set<Keyword> = []
    ) {
        self.title = title
        self.description = description
        self.descriptionAccessibilityID = descriptionAccessibilityID
        self.leadingIconKeyword = leadingIconKeyword
        self.titleKeywords = titleKeywords
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            if let title, !title.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                    if let leadingIconKeyword {
                        Image(systemName: leadingIconKeyword.visualStyle.symbolName)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(leadingIconKeyword.visualStyle.color)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(.primary)
                        .keywordShine(titleKeywords)
                }
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
