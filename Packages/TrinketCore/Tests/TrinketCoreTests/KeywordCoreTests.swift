import Foundation
import Testing
@testable import TrinketCore

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
        (.thorns, .damageType),
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
        #expect(Keyword.referenced(in: "Gain 5 Block and 5 Thorns.") == [.block, .thorns])
    }

    @Test func `bleed rules text matches turn count`() {
        #expect(Keyword.bleed.rulesText.contains("\(Effect.bleedDoTTurnCount) round"))
    }

    @Test func `highlight pattern compiles`() {
        #expect(Keyword.highlightRegex != nil)
        #expect(!Keyword.highlightPattern.isEmpty)
        #expect(!Keyword.termLookup.isEmpty)
    }

    @Test func `mana rules text matches empowerment tuning`() {
        #expect(Keyword.mana.rulesText.contains("3 Mana"))
        #expect(Keyword.mana.rulesText.contains("+1 Burn"))
    }

    @Test func `referenced text without keywords is empty`() {
        #expect(Keyword.referenced(in: "").isEmpty)
        #expect(Keyword.referenced(in: "Draw a card.").isEmpty)
        // Word-boundary negative: Blockade contains no boundary-delimited term.
        #expect(Keyword.referenced(in: "Blockade the door.").isEmpty)
    }

    @Test func `referenced resolves longest overlapping match`() {
        // "Burning" matches Burn (via status alias), not a separate keyword.
        #expect(Keyword.referenced(in: "Burning") == [.burn])
        #expect(Keyword.referenced(in: "Frozen") == [.freeze])
    }

    @Test func `term lookup covers every styled term`() {
        for (term, keyword) in Keyword.styledTerms {
            #expect(Keyword.termLookup[term.lowercased()] == keyword)
        }
    }

    @Test func `referenced keywords matches terms with straight and curly apostrophes`() {
        #expect(Keyword.referenced(in: "Survive while on Death's Door.") == [.deathsDoor])
        #expect(Keyword.referenced(in: "Survive while on Death’s Door.") == [.deathsDoor])
        #expect(Keyword.referenced(in: "death's door or death’s door") == [.deathsDoor])
    }

    @Test(arguments: Keyword.allCases)
    func `keyword critical hit legality aligns with category and restoration rules`(keyword: Keyword) {
        let expected = keyword.category == .damageType || keyword == .health || keyword == .leech
        #expect(keyword.allowsCriticalHits == expected, "\(keyword) crit legality should be \(expected)")
    }

    @Test func `statusName resolves alias when present or falls back to raw value`() {
        #expect(Keyword.burn.statusName == "Burning")
        #expect(Keyword.freeze.statusName == "Frozen")
        #expect(Keyword.stun.statusName == "Stunned")
        #expect(Keyword.poison.statusName == "Poisoned")
        #expect(Keyword.bleed.statusName == "Bleeding")
        #expect(Keyword.deathsDoor.statusName == "Death's Door")
        #expect(Keyword.physical.statusName == "Physical")
        #expect(Keyword.block.statusName == "Block")
        #expect(Keyword.holy.statusName == "Holy")
    }
}
