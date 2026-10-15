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
        guard let expression = Self.expression else {
            text = markedText
            spans = []
            return
        }
        let source = markedText as NSString
        var output = ""
        var spans: [Span] = []
        var cursor = 0
        for match in expression.matches(in: markedText, range: NSRange(location: 0, length: source.length)) {
            output += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let start = output.utf16.count
            let identifier = source.substring(with: match.range(at: 2))
            output += source.substring(with: match.range(at: 3))
            let range = start ..< output.utf16.count
            if source.substring(with: match.range(at: 1)) == "keyword",
               let keyword = Keyword.allCases.first(where: { String(describing: $0).lowercased() == identifier }) {
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
            values: Dictionary(uniqueKeysWithValues: values.map { ("\(prefix)_\($0.key)", $0.value) }),
        )
    }
}
