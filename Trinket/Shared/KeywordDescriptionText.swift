import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct KeywordDescriptionText: View {
    let text: String

    @State private var selectedKeyword: Keyword?

    var body: some View {
        Text(attributedText)
            .environment(\.openURL, OpenURLAction { url in
                guard let keyword = Keyword(glossaryURL: url) else {
                    return .systemAction
                }
                selectedKeyword = keyword
                return .handled
            })
            .popover(item: $selectedKeyword) { keyword in
                KeywordGlossaryPopover(keyword: keyword)
                    .presentationCompactAdaptation(.popover)
            }
    }

    private var attributedText: AttributedString {
        var attr = AttributedString(text)
        for (term, keyword) in Keyword.styledTerms {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(of: term, range: searchStart ..< text.endIndex) {
                if let startIdx = AttributedString.Index(range.lowerBound, within: attr),
                   let endIdx = AttributedString.Index(range.upperBound, within: attr) {
                    let styledRange = startIdx ..< endIdx
                    attr[styledRange].foregroundColor = keyword.visualStyle.color
                    attr[styledRange].inlinePresentationIntent = .stronglyEmphasized
                    attr[styledRange].link = keyword.glossaryURL
                    attr[styledRange].underlineStyle = .init(pattern: .solid, color: .clear)
                }
                searchStart = range.upperBound
            }
        }
        return attr
    }
}

private struct KeywordGlossaryPopover: View {
    let keyword: Keyword

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.tightSpacing) {
            HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                Text(keyword.rawValue)
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(keyword.visualStyle.color)

                Image(systemName: keyword.visualStyle.symbolName)
                    .foregroundStyle(keyword.visualStyle.color)
                    .accessibilityHidden(true)
            }

            Text(keyword.rulesText)
                .trinketTypography(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TrinketDesign.Metrics.sectionHeaderSpacing)
        .frame(maxWidth: 280, alignment: .leading)
        .trinketMaterial(.popover)
    }
}
