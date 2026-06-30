import SwiftUI

struct KeywordDescriptionText: View {
    let text: String

    var body: some View {
        Text(attributedText)
    }

    private var attributedText: AttributedString {
        var attr = AttributedString(text)
        for keyword in Keyword.allCases {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(of: keyword.rawValue, range: searchStart ..< text.endIndex) {
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
