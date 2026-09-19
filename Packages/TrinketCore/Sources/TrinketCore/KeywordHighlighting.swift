import Foundation

/// Text-search machinery for `Keyword` (highlighting + `referenced(in:)`).
///
/// Lives in its own file so the `Keyword` enum stays a data model
/// (cases, categories, aliases, inflections, rules copy) while this file owns
/// the compiled-regex singletons and matching behavior. Same module, same
/// public API — a pure file move.
public extension Keyword {
    internal static let styledTerms: [(term: String, keyword: Self)] = {
        var terms: [(String, Self)] = []
        for keyword in allCases {
            terms.append((keyword.rawValue, keyword))
            if let alias = keyword.statusAlias {
                terms.append((alias, keyword))
            }
            for inflection in keyword.inflections {
                terms.append((inflection, keyword))
            }
        }
        var seen = Set<String>()
        var unique: [(String, Self)] = []
        for (term, keyword) in terms {
            let lower = term.lowercased()
            if seen.insert(lower).inserted {
                unique.append((term, keyword))
            }
            if term.contains("'") {
                let curly = term.replacingOccurrences(of: "'", with: "’")
                if seen.insert(curly.lowercased()).inserted {
                    unique.append((curly, keyword))
                }
            } else if term.contains("’") {
                let straight = term.replacingOccurrences(of: "’", with: "'")
                if seen.insert(straight.lowercased()).inserted {
                    unique.append((straight, keyword))
                }
            }
        }
        return unique.sorted { $0.0.count > $1.0.count }
    }()

    static let highlightPattern: String = {
        let alternatives = styledTerms.map { NSRegularExpression.escapedPattern(for: $0.term) }
        return "\\b(?:\(alternatives.joined(separator: "|")))\\b"
    }()

    static let termLookup: [String: Self] = {
        var lookup: [String: Self] = [:]
        for (term, keyword) in styledTerms {
            lookup[term.lowercased()] = keyword
        }
        return lookup
    }()

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
        for match in regex.matches(in: text, options: [], range: fullRange) {
            let matched = nsText.substring(with: match.range).lowercased()
            guard let keyword = termLookup[matched], seen.insert(keyword).inserted else { continue }
            result.append(keyword)
        }
        return result
    }
}
