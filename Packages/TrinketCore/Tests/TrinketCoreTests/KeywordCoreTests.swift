import Testing
@testable import TrinketCore

struct KeywordCoreTests {
    @Test(arguments: Keyword.allCases)
    func `all keywords have readable rules text`(keyword: Keyword) {
        #expect(!keyword.rulesText.isEmpty, "\(keyword.rawValue) should have rules text")
    }

    @Test func `keyword emphasis preserves word boundaries aliases and appearance order`() {
        let cases: [(String, [Keyword])] = [
            ("Gain 1 Block when you deal Stun or Holy damage.", [.block, .stun, .holy]),
            ("Deal Stun then Bleed.", [.stun, .bleed]),
            ("Deal Bleed then Stun.", [.bleed, .stun]),
            ("Applies Burning then Frozen, then more Burning.", [.burn, .freeze]),
            ("deal poison and holy damage", [.poison, .holy]),
            ("Blocking then Blocked", [.block]),
            ("Heals for Health", [.health]),
            ("Gain 5 Block and 5 Thorns.", [.block, .thorns]),
            ("", []),
            ("Draw a card.", []),
            ("Blockade the door.", []),
            ("Survive while on Death's Door.", [.deathsDoor]),
            ("Survive while on Death’s Door.", [.deathsDoor]),
            ("death's door or death’s door", [.deathsDoor]),
        ]
        for (text, expected) in cases {
            #expect(Keyword.referenced(in: text) == expected, "\(text)")
        }
    }

    @Test func `bleed rules text matches turn count`() {
        #expect(Keyword.bleed.rulesText.contains("\(Effect.bleedDoTTurnCount) round"))
    }
}
