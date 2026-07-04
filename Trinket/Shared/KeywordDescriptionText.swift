import SwiftUI
import TrinketCore

struct KeywordDescriptionText: View {
    let text: String

    var body: some View {
        Text(attributedText)
    }

    private var attributedText: AttributedString {
        var attr = AttributedString(text)
        for (term, keyword) in Keyword.styledTerms {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(of: term, range: searchStart ..< text.endIndex) {
                if let startIdx = AttributedString.Index(range.lowerBound, within: attr),
                   let endIdx = AttributedString.Index(range.upperBound, within: attr) {
                    attr[startIdx ..< endIdx].foregroundColor = keyword.visualStyle.color
                    attr[startIdx ..< endIdx].inlinePresentationIntent = .stronglyEmphasized
                }
                searchStart = range.upperBound
            }
        }
        return attr
    }
}
