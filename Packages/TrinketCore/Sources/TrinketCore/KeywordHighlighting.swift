import Foundation

/// Shared terms for text highlighting and keyword extraction.
public extension Keyword {
    internal static let styledTerms: [(term: String, keyword: Self)] = {
        var seen = Set<String>()
        var unique: [(String, Self)] = []
        for keyword in allCases {
            let terms = [keyword.rawValue] + [keyword.statusAlias].compactMap(\.self) + keyword.inflections
            for term in terms {
                let alternate = term.contains("'")
                    ? term.replacingOccurrences(of: "'", with: "’")
                    : term.replacingOccurrences(of: "’", with: "'")
                for spelling in [term, alternate] where seen.insert(spelling.lowercased()).inserted {
                    unique.append((spelling, keyword))
                }
            }
        }
        return unique.sorted { $0.0.count > $1.0.count }
    }()

    static let highlightPattern: String = {
        let alternatives = styledTerms.map { NSRegularExpression.escapedPattern(for: $0.term) }
        return "\\b(?:\(alternatives.joined(separator: "|")))\\b"
    }()

    static let termLookup = Dictionary(uniqueKeysWithValues: styledTerms.map {
        ($0.term.lowercased(), $0.keyword)
    })

    static let highlightRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: highlightPattern,
        options: [.caseInsensitive],
    )

    static func referenced(in text: String) -> [Self] {
        guard let regex = highlightRegex else {
            assertionFailure("Keyword.highlightPattern failed to compile")
            return []
        }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var seen = Set<Self>()
        var result: [Self] = []
        regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match else { return }
            let matched = nsText.substring(with: match.range).lowercased()
            guard let keyword = termLookup[matched], seen.insert(keyword).inserted else { return }
            result.append(keyword)
        }
        return result
    }
}
