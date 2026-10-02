import Foundation
import SwiftUI
import TrinketCore
import TrinketDesignSystem

@MainActor
private final class KeywordAttributedTextCache {
    static let shared = KeywordAttributedTextCache()
    private let cache: NSCache<NSString, CacheEntry> = {
        let c = NSCache<NSString, CacheEntry>()
        c.countLimit = 200
        return c
    }()

    private final class CacheEntry: Sendable {
        let text: AttributedString

        init(_ text: AttributedString) {
            self.text = text
        }
    }

    func cachedText(for text: String) -> AttributedString? {
        cache.object(forKey: text as NSString)?.text
    }

    func storeText(_ attributedText: AttributedString, for text: String) {
        cache.setObject(CacheEntry(attributedText), forKey: text as NSString)
    }
}

private let keywordHighlightRegex: NSRegularExpression? = Keyword.highlightRegex

private let keywordHighlightLookup: [String: Keyword] = Keyword.termLookup

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
        if let cached = KeywordAttributedTextCache.shared.cachedText(for: text) {
            return cached
        }
        var attr = AttributedString(text)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        keywordHighlightRegex?.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match,
                  let keyword = keywordHighlightLookup[nsText.substring(with: match.range).lowercased()],
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
        KeywordAttributedTextCache.shared.storeText(attr, for: text)
        return attr
    }
}
