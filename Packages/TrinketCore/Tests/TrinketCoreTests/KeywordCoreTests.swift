import Foundation
import Testing
import TrinketCore

struct KeywordCoreTests {
    @Test func `keyword raw values are unique`() throws {
        let rawValues = Keyword.allCases.map(\.rawValue)
        try #expect(rawValues.count == Set(rawValues).count)
    }

    @Test(arguments: Keyword.allCases)
    func `all keywords have rules text and category`(keyword: Keyword) throws {
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
    func `keyword category`(keyword: Keyword, category: Keyword.Category) throws {
        try #expect(keyword.category == category, "\(keyword.rawValue) should be \(category)")
    }

    @Test func `category cases are unique and non empty`() throws {
        let rawValues = Keyword.Category.allCases.map(\.rawValue)
        try #expect(rawValues.count == Set(rawValues).count)
        try #expect(rawValues.allSatisfy { !$0.isEmpty })
    }

    @Test func `referenced keywords extraction maintains appearance order`() throws {
        let text = "Gain 1 Block when you deal Stun or Holy damage."
        let keywords = Keyword.referenced(in: text)
        try #expect(keywords == [.block, .stun, .holy])
        try #expect(!keywords.contains(.burn))

        let stunBeforeBleed = "Deal Stun then Bleed."
        try #expect(Keyword.referenced(in: stunBeforeBleed) == [.stun, .bleed])

        let bleedBeforeStun = "Deal Bleed then Stun."
        try #expect(Keyword.referenced(in: bleedBeforeStun) == [.bleed, .stun])
    }

    @Test func `referenced keywords matches status aliases and deduplicates`() throws {
        let text = "Applies Burning then Frozen, then more Burning."
        let keywords = Keyword.referenced(in: text)
        try #expect(keywords == [.burn, .freeze])

        let caseInsensitive = "deal poison and holy damage"
        try #expect(Keyword.referenced(in: caseInsensitive) == [.poison, .holy])
    }

    @Test func `bleed rules text matches turn count`() throws {
        try #expect(Keyword.bleed.rulesText.contains("\(Effect.bleedDoTTurnCount) rounds"))
    }
}
