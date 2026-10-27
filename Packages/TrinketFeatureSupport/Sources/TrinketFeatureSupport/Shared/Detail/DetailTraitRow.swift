import SwiftUI
import TrinketCore
import TrinketDesignSystem

public struct DetailTraitRow: View {
    var title: String?
    let description: String
    var comparisonDescription: String?
    private var localizedDescription: LocalizedGameText?
    private var localizedTitle: LocalizedStringResource?
    var descriptionAccessibilityID: String?
    var leadingIconKeyword: Keyword?
    var leadingIcon: GameIcon?
    var indicators: [DetailChangeIndicator]
    var titleColor: Color?
    var titleShine: Shine
    var titlePrefix: String?
    var titlePrefixShine: Shine

    public init(
        title: String? = nil,
        description: String,
        comparisonDescription: String? = nil,
        descriptionAccessibilityID: String? = nil,
        leadingIconKeyword: Keyword? = nil,
        leadingIcon: GameIcon? = nil,
        indicators: [DetailChangeIndicator] = [],
        titleColor: Color? = nil,
        titleShine: Shine = .none,
        titlePrefix: String? = nil,
        titlePrefixShine: Shine = .none,
        localizedDescription: LocalizedGameText? = nil,
        localizedTitle: LocalizedStringResource? = nil,
    ) {
        self.title = title
        self.description = description
        self.comparisonDescription = comparisonDescription
        self.descriptionAccessibilityID = descriptionAccessibilityID
        self.leadingIconKeyword = leadingIconKeyword
        self.leadingIcon = leadingIcon
        self.indicators = indicators
        self.titleColor = titleColor
        self.titleShine = titleShine
        self.titlePrefix = titlePrefix
        self.titlePrefixShine = titlePrefixShine
        self.localizedDescription = localizedDescription
        self.localizedTitle = localizedTitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            if !(title?.isEmpty ?? true) || !(titlePrefix?.isEmpty ?? true) {
                HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Spacing.extraSmall) {
                    if let leadingIcon {
                        GameIconImage(leadingIcon)
                            .trinketTypography(.cardTitle)
                            .foregroundStyle(titleColor ?? .primary)
                            .accessibilityHidden(true)
                    } else if let leadingIconKeyword {
                        if leadingIconKeyword == .gold {
                            HomesteadResourceArtwork(resource: .gold)
                                .frame(width: 18, height: 18)
                                .accessibilityHidden(true)
                        } else {
                            GameIconImage(leadingIconKeyword.visualStyle.icon)
                                // UIStyleCheck: allow - SF Symbol glyph sizing, not copy
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(leadingIconKeyword.visualStyle.color)
                                .accessibilityHidden(true)
                        }
                    }
                    DetailChangeIndicators(indicators: indicators)
                        .trinketTypography(.cardTitle)
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
                GameLabel(titlePrefix, balanced: true)
                    .trinketTypography(.cardTitle)
                    .shineText(titlePrefixShine)
                    .foregroundStyle(.primary)
                    .trinketFittedText()
            }
            if let title, !title.isEmpty {
                Group {
                    if let localizedTitle {
                        GameLabel(localizedTitle, balanced: true)
                    } else {
                        GameLabel(title, balanced: true)
                    }
                }
                .trinketTypography(.cardTitle)
                .shineText(titleShine)
                .foregroundStyle(titleColor ?? .primary)
                .trinketFittedText()
            }
        }
    }

    @ViewBuilder
    private var descriptionText: some View {
        let text = keywordText
            .trinketTypography(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
        if let descriptionAccessibilityID {
            text.accessibilityIdentifier(descriptionAccessibilityID)
        } else {
            text
        }
    }

    @ViewBuilder
    private var keywordText: some View {
        if let localizedDescription {
            KeywordDescriptionText(description: localizedDescription)
        } else {
            KeywordDescriptionText(text: description, comparisonDescription: comparisonDescription)
        }
    }
}
