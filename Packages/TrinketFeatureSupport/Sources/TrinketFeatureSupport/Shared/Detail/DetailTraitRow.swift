import SwiftUI
import TrinketCore
import TrinketDesignSystem

public struct DetailTraitRow: View {
    var title: String?
    let description: String
    var descriptionAccessibilityID: String?
    var leadingIconKeyword: Keyword?
    var titleShine: Shine
    var titlePrefix: String?
    var titlePrefixShine: Shine

    public init(
        title: String? = nil,
        description: String,
        descriptionAccessibilityID: String? = nil,
        leadingIconKeyword: Keyword? = nil,
        titleShine: Shine = .none,
        titlePrefix: String? = nil,
        titlePrefixShine: Shine = .none,
    ) {
        self.title = title
        self.description = description
        self.descriptionAccessibilityID = descriptionAccessibilityID
        self.leadingIconKeyword = leadingIconKeyword
        self.titleShine = titleShine
        self.titlePrefix = titlePrefix
        self.titlePrefixShine = titlePrefixShine
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            if !(title?.isEmpty ?? true) || !(titlePrefix?.isEmpty ?? true) {
                HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Spacing.extraSmall) {
                    if let leadingIconKeyword {
                        if leadingIconKeyword == .gold {
                            HomesteadResourceArtwork(resource: .gold)
                                .frame(width: 18, height: 18)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: leadingIconKeyword.visualStyle.symbolName)
                                // UIStyleCheck: allow - SF Symbol glyph sizing, not copy
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(leadingIconKeyword.visualStyle.color)
                                .accessibilityHidden(true)
                        }
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
                Text(balanced: titlePrefix)
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(.primary)
                    .trinketFittedText()
                    .shineText(titlePrefixShine)
            }
            if let title, !title.isEmpty {
                Text(balanced: title)
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(.primary)
                    .trinketFittedText()
                    .shineText(titleShine)
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
