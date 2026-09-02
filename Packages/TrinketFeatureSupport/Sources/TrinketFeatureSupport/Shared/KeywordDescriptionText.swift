import Foundation
import SwiftUI
import TrinketCore
import TrinketDesignSystem

@MainActor
final class KeywordAttributedTextCache {
    static let shared = KeywordAttributedTextCache()
    private let cache: NSCache<NSString, CacheEntry> = {
        let c = NSCache<NSString, CacheEntry>()
        c.countLimit = 200
        return c
    }()

    private final class CacheEntry: Sendable {
        let spans: [KeywordSpan]

        init(_ spans: [KeywordSpan]) {
            self.spans = spans
        }
    }

    func cachedSpans(for text: String) -> [KeywordSpan]? {
        cache.object(forKey: text as NSString)?.spans
    }

    func storeSpans(_ spans: [KeywordSpan], for text: String) {
        cache.setObject(CacheEntry(spans), forKey: text as NSString)
    }
}

struct KeywordSpan: Sendable {
    let range: NSRange
    let keyword: Keyword
}

private let keywordHighlightRegex: NSRegularExpression? = {
    let alternatives = Keyword.styledTerms
        .map { NSRegularExpression.escapedPattern(for: $0.term) }
        .joined(separator: "|")
    return try? NSRegularExpression(
        pattern: "\\b(?:\(alternatives))\\b",
        options: [.caseInsensitive],
    )
}()

private let keywordHighlightLookup: [String: Keyword] = {
    var lookup: [String: Keyword] = [:]
    for (term, keyword) in Keyword.styledTerms {
        lookup[term.lowercased()] = keyword
    }
    return lookup
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
        let spans: [KeywordSpan]
        if let cached = KeywordAttributedTextCache.shared.cachedSpans(for: text) {
            spans = cached
        } else {
            spans = highlightSpans(in: text)
            KeywordAttributedTextCache.shared.storeSpans(spans, for: text)
        }
        var attr = AttributedString(text)
        for span in spans {
            guard let swiftRange = Range(span.range, in: text),
                  let startIdx = AttributedString.Index(swiftRange.lowerBound, within: attr),
                  let endIdx = AttributedString.Index(swiftRange.upperBound, within: attr)
            else { continue }
            let styledRange = startIdx ..< endIdx
            attr[styledRange].foregroundColor = span.keyword.visualStyle.color
            attr[styledRange].inlinePresentationIntent = .stronglyEmphasized
        }
        return attr
    }

    private static func highlightSpans(in text: String) -> [KeywordSpan] {
        guard let regex = keywordHighlightRegex else { return [] }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        return regex.matches(in: text, options: [], range: fullRange).compactMap { match in
            let matched = (text as NSString).substring(with: match.range).lowercased()
            guard let keyword = keywordHighlightLookup[matched] else { return nil }
            return KeywordSpan(range: match.range, keyword: keyword)
        }
    }
}
