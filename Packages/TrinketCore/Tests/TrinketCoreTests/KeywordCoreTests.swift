import Foundation
import Testing
import TrinketCore

struct KeywordCoreTests {
    @Test func `keyword raw values are unique`() {
        let rawValues = Keyword.allCases.map(\.rawValue)
        #expect(rawValues.count == Set(rawValues).count)
    }

    @Test(arguments: Keyword.allCases)
    func `all keywords have rules text and category`(keyword: Keyword) {
        #expect(!keyword.rulesText.isEmpty, "\(keyword.rawValue) should have rules text")
        #expect(!keyword.rulesText.hasSuffix("."), "\(keyword.rawValue) rules text should omit trailing period")
        #expect(!keyword.category.rawValue.isEmpty, "\(keyword.rawValue) should have a category")
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
    func `keyword category`(keyword: Keyword, category: Keyword.Category) {
        #expect(keyword.category == category, "\(keyword.rawValue) should be \(category)")
    }

    @Test func `category cases are unique and non empty`() {
        let rawValues = Keyword.Category.allCases.map(\.rawValue)
        #expect(rawValues.count == Set(rawValues).count)
        #expect(rawValues.allSatisfy { !$0.isEmpty })
    }

    @Test func `referenced keywords extraction maintains appearance order`() {
        let text = "Gain 1 Block when you deal Stun or Holy damage."
        let keywords = Keyword.referenced(in: text)
        #expect(keywords == [.block, .stun, .holy])
        #expect(!keywords.contains(.burn))

        let stunBeforeBleed = "Deal Stun then Bleed."
        #expect(Keyword.referenced(in: stunBeforeBleed) == [.stun, .bleed])

        let bleedBeforeStun = "Deal Bleed then Stun."
        #expect(Keyword.referenced(in: bleedBeforeStun) == [.bleed, .stun])
    }

    @Test func `referenced keywords matches status aliases and deduplicates`() {
        let text = "Applies Burning then Frozen, then more Burning."
        let keywords = Keyword.referenced(in: text)
        #expect(keywords == [.burn, .freeze])

        let caseInsensitive = "deal poison and holy damage"
        #expect(Keyword.referenced(in: caseInsensitive) == [.poison, .holy])
    }

    @Test func `referenced keywords resolve inflections to their keyword`() {
        #expect(Keyword.referenced(in: "Blocking then Blocked") == [.block])
        #expect(Keyword.referenced(in: "Heals for Health") == [.health])
    }

    @Test func `bleed rules text matches turn count`() {
        #expect(Keyword.bleed.rulesText.contains("\(Effect.bleedDoTTurnCount) round"))
    }
}
