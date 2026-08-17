import SwiftUI
import TrinketCore
import TrinketDesignSystem

public struct KeywordDescriptionText: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(attributedText)
    }

    private var attributedText: AttributedString {
        var attr = AttributedString(text)
        for (term, keyword) in Keyword.styledTerms {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(of: term, options: .caseInsensitive, range: searchStart ..< text.endIndex) {
                if let startIdx = AttributedString.Index(range.lowerBound, within: attr),
                   let endIdx = AttributedString.Index(range.upperBound, within: attr) {
                    let styledRange = startIdx ..< endIdx
                    attr[styledRange].foregroundColor = keyword.visualStyle.color
                    attr[styledRange].inlinePresentationIntent = .stronglyEmphasized
                }
                searchStart = range.upperBound
            }
        }
        return attr
    }
}
