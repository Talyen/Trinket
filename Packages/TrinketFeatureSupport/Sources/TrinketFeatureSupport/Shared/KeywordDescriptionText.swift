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
        c.totalCostLimit = 1 * 1024 * 1024
        return c
    }()

    private final class CacheEntry {
        let value: AttributedString

        init(_ value: AttributedString) {
            self.value = value
        }
    }

    func cachedAttributedText(for text: String) -> AttributedString? {
        cache.object(forKey: text as NSString)?.value
    }

    func storeAttributedText(_ attr: AttributedString, for text: String) {
        let entry = CacheEntry(attr)
        let cost = text.utf8.count + attr.characters.count
        cache.setObject(entry, forKey: text as NSString, cost: cost)
    }
}

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
        if let cached = KeywordAttributedTextCache.shared.cachedAttributedText(for: text) {
            return cached
        }
        var attr = AttributedString(text)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        for (regex, keyword) in Keyword.styledRegexes {
            let matches = regex.matches(in: text, options: [], range: fullRange)
            for match in matches {
                let nsRange = match.range
                guard let swiftRange = Range(nsRange, in: text),
                      let startIdx = AttributedString.Index(swiftRange.lowerBound, within: attr),
                      let endIdx = AttributedString.Index(swiftRange.upperBound, within: attr)
                else { continue }
                let styledRange = startIdx ..< endIdx
                attr[styledRange].foregroundColor = keyword.visualStyle.color
                attr[styledRange].inlinePresentationIntent = .stronglyEmphasized
            }
        }
        KeywordAttributedTextCache.shared.storeAttributedText(attr, for: text)
        return attr
    }
}
