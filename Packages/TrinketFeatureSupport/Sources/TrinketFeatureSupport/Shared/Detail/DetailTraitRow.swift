import SwiftUI
import TrinketCore
import TrinketDesignSystem

public struct DetailTraitRow: View {
    var title: String?
    let description: String
    var descriptionAccessibilityID: String?
    var leadingIconKeyword: Keyword?
    var titleKeywords: Set<Keyword>
    var titleShineColors: [Color]?
    var titlePrefix: String?
    var titlePrefixShineColors: [Color]?

    public init(
        title: String? = nil,
        description: String,
        descriptionAccessibilityID: String? = nil,
        leadingIconKeyword: Keyword? = nil,
        titleKeywords: Set<Keyword> = [],
        titleShineColors: [Color]? = nil,
        titlePrefix: String? = nil,
        titlePrefixShineColors: [Color]? = nil
    ) {
        self.title = title
        self.description = description
        self.descriptionAccessibilityID = descriptionAccessibilityID
        self.leadingIconKeyword = leadingIconKeyword
        self.titleKeywords = titleKeywords
        self.titleShineColors = titleShineColors
        self.titlePrefix = titlePrefix
        self.titlePrefixShineColors = titlePrefixShineColors
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            if !(title?.isEmpty ?? true) || !(titlePrefix?.isEmpty ?? true) {
                HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                    if let leadingIconKeyword {
                        Image(systemName: leadingIconKeyword.visualStyle.symbolName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(leadingIconKeyword.visualStyle.color)
                            .accessibilityHidden(true)
                    }
                    titleText
                }
            }

            descriptionText
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trinketSurface(.secondary)
    }

    private var titleText: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if let titlePrefix, !titlePrefix.isEmpty {
                let prefix = Text(balanced: titlePrefix)
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(.primary)
                if let titlePrefixShineColors, !titlePrefixShineColors.isEmpty {
                    prefix.colorShine(titlePrefixShineColors)
                } else {
                    prefix
                }
            }
            if let title, !title.isEmpty {
                let base = Text(balanced: title)
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(.primary)
                if let titleShineColors, !titleShineColors.isEmpty {
                    base.colorShine(titleShineColors)
                } else {
                    base.keywordShine(titleKeywords)
                }
            }
        }
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
