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
        (.cleanse, .restoration),
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

    @Test func referencedKeywordsExtractionMaintainsAppearanceOrder() throws {
        let text = "Gain 1 Block when you deal Stun or Holy damage."
        let keywords = Keyword.referenced(in: text)
        try #expect(keywords == [.block, .stun, .holy])
        try #expect(!keywords.contains(.burn))

        // Ensure shorter keyword ("Stun" 4 chars) appearing before longer keyword ("Bleed" 5 chars)
        // is preserved in exact appearance order (not term length descending).
        let stunBeforeBleed = "Deal Stun then Bleed."
        try #expect(Keyword.referenced(in: stunBeforeBleed) == [.stun, .bleed])

        let bleedBeforeStun = "Deal Bleed then Stun."
        try #expect(Keyword.referenced(in: bleedBeforeStun) == [.bleed, .stun])
    }

    @Test func referencedKeywordsMatchesStatusAliasesAndDeduplicates() throws {
        let text = "Applies Burning then Frozen, then more Burning."
        let keywords = Keyword.referenced(in: text)
        try #expect(keywords == [.burn, .freeze])

        let caseInsensitive = "deal poison and holy damage"
        try #expect(Keyword.referenced(in: caseInsensitive) == [.poison, .holy])
    }

    @Test func bleedRulesTextMatchesTurnCount() throws {
        try #expect(Keyword.bleed.rulesText.contains("\(Effect.bleedDoTTurnCount) rounds"))
    }
}
