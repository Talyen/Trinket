import Foundation
import Testing
@testable import TrinketCore

struct LocalizedGameTextTests {
    @Test func `semantic values follow named identities through translated order and UTF16 ranges`() {
        let rendered = LocalizedGameText(
            markedText: "🛡️ <value id=\"turns\">2</value>回、<keyword id=\"burn\">炎上</keyword><value id=\"damage\">9</value>",
            values: ["damage": 9, "turns": 2],
        )
        #expect(rendered.text == "🛡️ 2回、炎上9")
        #expect(rendered.values == ["damage": 9, "turns": 2])
        let burn = rendered.spans.first {
            if case .keyword(.burn) = $0.meaning {
                true
            } else {
                false
            }
        }
        let source = rendered.text as NSString
        #expect(burn.map { source.substring(with: NSRange(location: $0.utf16Range.lowerBound, length: $0.utf16Range.count)) } == "炎上")
    }

    @Test func `joined descriptions keep separate quantities exact and collision free`() {
        let first = LocalizedGameText(markedText: "<value id=\"damage\">huge</value>", values: ["damage": Int.max])
        let second = LocalizedGameText(markedText: "<value id=\"damage\">small</value>", values: ["damage": 1])
        let joined = LocalizedGameText.joining([first, second])
        #expect(joined.values == ["part_0_damage": Int.max, "part_1_damage": 1])
    }

    @Test func `explicit locale changes presentation without changing serialized keyword identities`() throws {
        #expect(CoreCopy.description("Burning", locale: Locale(identifier: "en")).text == "Burning")
        let keyword = Keyword.burn
        let canonical = try JSONEncoder().encode(keyword)
        let english = keyword.localizedName(locale: Locale(identifier: "en"))
        for language in ["ja", "ko", "de", "zh-Hant", "fr"] {
            #expect(keyword.localizedName(locale: Locale(identifier: language)) != english)
            #expect(try JSONEncoder().encode(keyword) == canonical)
        }
        #expect(keyword.localizedName(locale: Locale(identifier: "en")) == english)
    }
}
