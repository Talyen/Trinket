import Foundation
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public struct KeywordDescriptionText: View {
    @Environment(\.locale) private var locale
    private let source: String?
    private let comparisonSource: String?
    private let description: LocalizedGameText?
    private let comparison: LocalizedGameText?

    public init(text: String, comparisonDescription: String? = nil) {
        source = text
        comparisonSource = comparisonDescription
        description = nil
        comparison = nil
    }

    public init(description: LocalizedGameText, comparison: LocalizedGameText? = nil) {
        source = nil
        comparisonSource = nil
        self.description = description
        self.comparison = comparison
    }

    public var body: some View {
        let description = description ?? ContentCopy.description(source ?? "", locale: locale)
        let comparison = comparison ?? comparisonSource.map { ContentCopy.description($0, locale: locale) }
        Text(Self.attributedText(for: description, comparison: comparison))
    }

    public static func attributedText(for text: String, locale: Locale = .current) -> AttributedString {
        attributedText(for: ContentCopy.description(text, locale: locale))
    }

    public static func attributedText(for description: LocalizedGameText, comparison: LocalizedGameText? = nil) -> AttributedString {
        var attributed = AttributedString(description.text)
        // Catalog reworks can reuse a quantity ID for a different stat in saved copy.
        let before = comparison.flatMap {
            semanticComponents(in: $0) == semanticComponents(in: description) ? $0.values : nil
        } ?? [:]
        for span in description.spans {
            let range = NSRange(location: span.utf16Range.lowerBound, length: span.utf16Range.count)
            guard let swiftRange = Range(range, in: description.text),
                  let start = AttributedString.Index(swiftRange.lowerBound, within: attributed),
                  let end = AttributedString.Index(swiftRange.upperBound, within: attributed)
            else { continue }
            switch span.meaning {
            case let .keyword(keyword):
                attributed[start ..< end].foregroundColor = keyword.visualStyle.color
                attributed[start ..< end].inlinePresentationIntent = .stronglyEmphasized
            case let .value(identifier, value):
                if let oldValue = before[identifier], value != oldValue {
                    attributed[start ..< end].foregroundColor = value > oldValue
                        ? TrinketDesign.Colors.success : TrinketDesign.Colors.destructive
                }
            }
        }
        return attributed
    }

    private enum SemanticComponent: Hashable {
        case keyword(Keyword)
        case quantity(String)
    }

    private static func semanticComponents(in text: LocalizedGameText) -> [SemanticComponent: Int] {
        text.spans.reduce(into: [:]) { components, span in
            let component: SemanticComponent = switch span.meaning {
            case let .keyword(keyword): .keyword(keyword)
            case let .value(identifier, _): .quantity(identifier)
            }
            components[component, default: 0] += 1
        }
    }
}
