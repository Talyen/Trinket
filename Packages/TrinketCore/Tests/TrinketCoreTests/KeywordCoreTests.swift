import Foundation
import Testing
import TrinketCore

struct KeywordCoreTests {
    @Test func keywordRawValuesAreUnique() throws {
        let rawValues = Keyword.allCases.map(\.rawValue)
        try #expect(rawValues.count == Set(rawValues).count)
    }

    @Test(arguments: Keyword.allCases)
    func allKeywordsHaveRulesTextAndCategory(keyword: Keyword) throws {
        try #expect(!keyword.rulesText.isEmpty, "\(keyword.rawValue) should have rules text")
        try #expect(!keyword.rulesText.hasSuffix("."), "\(keyword.rawValue) rules text should omit trailing period")
        try #expect(!keyword.category.rawValue.isEmpty, "\(keyword.rawValue) should have a category")
    }

    @Test(arguments: [
        (Keyword.physical, Keyword.Category.damageType),
        (.burn, .damageType),
        (.poison, .damageType),
        (.bleed, .damageType),
        (.holy, .damageType),
        (.freeze, .damageType),
        (.stun, .damageType),
        (.block, .mitigation),
        (.dodge, .mitigation),
        (.purge, .mitigation),
        (.health, .restoration),
        (.leech, .restoration),
        (.deathsDoor, .restoration),
        (.gold, .resource),
        (.mana, .resource),
    ])
    func keywordCategory(keyword: Keyword, category: Keyword.Category) throws {
        try #expect(keyword.category == category, "\(keyword.rawValue) should be \(category)")
    }

    @Test func categoryCasesAreUniqueAndNonEmpty() throws {
        let rawValues = Keyword.Category.allCases.map(\.rawValue)
        try #expect(rawValues.count == Set(rawValues).count)
        try #expect(rawValues.allSatisfy { !$0.isEmpty })
    }

    @Test func referencedKeywordsExtraction() throws {
        let text = "Gain 1 Block when you deal Stun or Holy damage."
        let keywords = Keyword.referenced(in: text)
        try #expect(keywords.contains(.block))
        try #expect(keywords.contains(.stun))
        try #expect(keywords.contains(.holy))
        try #expect(!keywords.contains(.burn))
    }

    @Test func bleedRulesTextMatchesTurnCount() throws {
        try #expect(Keyword.bleed.rulesText.contains("\(Effect.bleedDoTTurnCount) rounds"))
    }
}
