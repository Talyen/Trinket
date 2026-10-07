import Foundation
import SwiftUI
import TrinketCore
import TrinketDesignSystem

private final class KeywordAttributedTextEntry: Sendable {
    let text: AttributedString

    init(_ text: AttributedString) {
        self.text = text
    }
}

@MainActor
private let keywordAttributedTextCache: NSCache<NSString, KeywordAttributedTextEntry> = {
    let cache = NSCache<NSString, KeywordAttributedTextEntry>()
    cache.countLimit = 200
    return cache
}()

public struct KeywordDescriptionText: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(Self.attributedText(for: text))
    }

    @MainActor
    public static func attributedText(for text: String) -> AttributedString {
        if let cached = keywordAttributedTextCache.object(forKey: text as NSString)?.text {
            return cached
        }
        var attr = AttributedString(text)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        Keyword.highlightRegex?.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match,
                  let keyword = Keyword.termLookup[nsText.substring(with: match.range).lowercased()],
                  let swiftRange = Range(match.range, in: text),
                  let startIdx = AttributedString.Index(swiftRange.lowerBound, within: attr),
                  let endIdx = AttributedString.Index(swiftRange.upperBound, within: attr)
            else { return }
            let styledRange = startIdx ..< endIdx
            attr[styledRange].foregroundColor = keyword.visualStyle.color
            attr[styledRange].inlinePresentationIntent = .stronglyEmphasized
        }
        // Retain semantic Color values, so environment resolution stays live.
        // AttributedString copies let callers restyle without changing the cache.
        keywordAttributedTextCache.setObject(KeywordAttributedTextEntry(attr), forKey: text as NSString)
        return attr
    }
}
