import Foundation
import SwiftUI
import TrinketContent
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
    private let corruptedPower: ItemAffixPower?

    public init(text: String, corruptedPower: ItemAffixPower? = nil) {
        self.text = text
        self.corruptedPower = corruptedPower
    }

    public var body: some View {
        Text(highlightedText)
    }

    private var highlightedText: AttributedString {
        var attributed = Self.attributedText(for: text)
        guard let corruptedPower, let baseline = corruptedPower.corruptionBaselineDescription else { return attributed }
        let before = DescriptionMagnitude.matches(in: baseline)
        let after = DescriptionMagnitude.matches(in: corruptedPower.description)
        let displayed = DescriptionMagnitude.matches(in: text)
        // Compare unscaled rolls, then style the matching displayed quantity. Weapon
        // scaling and keyword colors must not change the corruption's direction.
        guard before.count == after.count, after.count == displayed.count else { return attributed }
        for index in after.indices where after[index].value != before[index].value {
            guard let start = AttributedString.Index(displayed[index].range.lowerBound, within: attributed),
                  let end = AttributedString.Index(displayed[index].range.upperBound, within: attributed)
            else { continue }
            attributed[start ..< end].foregroundColor = after[index].value > before[index].value
                ? TrinketDesign.Colors.success : TrinketDesign.Colors.destructive
        }
        return attributed
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

private struct DescriptionMagnitude {
    let range: Range<String.Index>
    let value: Double

    /// A single buff/debuff is written as an article by the affix formatter.
    private static let regex = try? NSRegularExpression(pattern: #"\d+(?:\.\d+)?%?|\ba(?= (?:buff|debuff)\b)"#)

    static func matches(in text: String) -> [Self] {
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return regex?.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let token = text[range]
            guard let value = token == "a" ? 1 : Double(token.replacingOccurrences(of: "%", with: "")) else { return nil }
            return Self(range: range, value: value)
        } ?? []
    }
}
