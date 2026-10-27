import Foundation

/// Rendered copy carries stable semantic identities across word order and inflection changes.
public struct LocalizedGameText: Sendable {
    public struct Span: Sendable {
        public enum Meaning: Sendable {
            case keyword(Keyword)
            case value(String, Int)
        }

        public let utf16Range: Range<Int>
        public let meaning: Meaning
    }

    public let text: String
    public let markedText: String
    public let spans: [Span]

    private static let expression = try? NSRegularExpression(pattern: #"<(keyword|value) id="([a-z0-9_]+)">([^<]*)</\1>"#)
    private static let keywordByID: [String: Keyword] = Dictionary(
        uniqueKeysWithValues: Keyword.allCases.lazy.map { (String(describing: $0).lowercased(), $0) },
    )

    public init(_ resource: LocalizedStringResource, locale: Locale, values: [String: Int] = [:]) {
        var resource = resource
        resource.locale = locale
        self.init(markedText: String(localized: resource), values: values)
    }

    public init(verbatim text: String) {
        self.text = text
        markedText = text
        spans = []
    }

    public init(markedText: String, values: [String: Int] = [:]) {
        self.markedText = markedText
        guard markedText.contains("<"), let expression = Self.expression else {
            text = markedText
            spans = []
            return
        }
        let source = markedText as NSString
        var output = ""
        var spans: [Span] = []
        var cursor = 0
        var outputLength = 0
        expression.enumerateMatches(in: markedText, range: NSRange(location: 0, length: source.length)) { match, _, _ in
            guard let match else { return }
            let prefix = NSRange(location: cursor, length: match.range.location - cursor)
            output += source.substring(with: prefix)
            outputLength += prefix.length
            let start = outputLength
            let identifier = source.substring(with: match.range(at: 2))
            let content = match.range(at: 3)
            output += source.substring(with: content)
            outputLength += content.length
            let range = start ..< outputLength
            if source.substring(with: match.range(at: 1)) == "keyword",
               let keyword = Self.keywordByID[identifier] {
                spans.append(Span(utf16Range: range, meaning: .keyword(keyword)))
            } else if let value = values[identifier] {
                spans.append(Span(utf16Range: range, meaning: .value(identifier, value)))
            }
            cursor = match.range.upperBound
        }
        output += source.substring(from: cursor)
        text = output
        self.spans = spans
    }

    public var values: [String: Int] {
        spans.reduce(into: [:]) { values, span in
            if case let .value(identifier, value) = span.meaning {
                values[identifier] = value
            }
        }
    }

    public static func joining(_ parts: [Self], separator: String = "\n") -> Self {
        var output = ""
        var values: [String: Int] = [:]
        for (index, part) in parts.enumerated() {
            if index > 0 {
                output += separator
            }
            output += part.markedText.replacingOccurrences(of: "<value id=\"", with: "<value id=\"part_\(index)_")
            for (identifier, value) in part.values {
                values["part_\(index)_\(identifier)"] = value
            }
        }
        return Self(markedText: output, values: values)
    }

    public func scoped(to prefix: String) -> Self {
        Self(
            markedText: markedText.replacingOccurrences(of: "<value id=\"", with: "<value id=\"\(prefix)_"),
            values: Dictionary(uniqueKeysWithValues: values.lazy.map { ("\(prefix)_\($0.key)", $0.value) }),
        )
    }
}
