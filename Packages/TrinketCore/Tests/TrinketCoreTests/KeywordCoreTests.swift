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

    @Test(arguments: Keyword.allCases)
    func glossaryURLRoundTrips(keyword: Keyword) throws {
        let url = keyword.glossaryURL
        try #expect(url.scheme == Keyword.glossaryURLScheme)
        try #expect(Keyword(glossaryURL: url) == keyword)
    }

    @Test func glossaryURLRejectsForeignSchemes() throws {
        let url = try #require(URL(string: "https://example.com/burn"))
        try #expect(Keyword(glossaryURL: url) == nil)
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
        (.mana, .resource)
    ])
    func keywordCategory(keyword: Keyword, category: Keyword.Category) throws {
        try #expect(keyword.category == category, "\(keyword.rawValue) should be \(category)")
    }

    @Test func categoryCasesAreUniqueAndNonEmpty() throws {
        let rawValues = Keyword.Category.allCases.map(\.rawValue)
        try #expect(rawValues.count == Set(rawValues).count)
        try #expect(rawValues.allSatisfy { !$0.isEmpty })
    }
}
