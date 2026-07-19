import Foundation
import Testing
import TrinketCore

struct KeywordCoreTests {
    @Test func allKeywordsAreCovered() throws {
        let expected: Set = [
            "Physical", "Burn", "Stun", "Block", "Health", "Gold", "Holy", "Poison",
            "Bleed", "Leech", "Freeze", "Dodge", "Purge", "Mana", "Death's Door"
        ]
        let actual = Set(Keyword.allCases.map(\.rawValue))
        try #expect(expected == actual)
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

    @Test func approvedRulesText() throws {
        try #expect(Keyword.physical.rulesText == "Physical direct damage type")
        try #expect(Keyword.burn.rulesText == "Burn deals damage each turn and fades quickly")
        try #expect(Keyword.poison.rulesText == "Poison deals damage each turn and fades slowly")
        try #expect(Keyword.bleed.rulesText == "Bleed deals damage each turn for 3 turns")
        try #expect(Keyword.stun.rulesText == "Stun damage builds up and eventually causes the loss of a turn")
        try #expect(Keyword.freeze.rulesText == "Freeze damage builds up and eventually causes the loss of a turn")
        try #expect(Keyword.holy.rulesText == "Holy direct damage type")
        try #expect(Keyword.block.rulesText == "Prevents Health damage and fades quickly")
        try #expect(Keyword.dodge.rulesText == "Dodge avoids an attack completely")
        try #expect(Keyword.purge.rulesText == "Purge removes a beneficial effect")
        try #expect(Keyword.health.rulesText == "Health keeps you alive")
        try #expect(Keyword.leech.rulesText == "Leech damage heals the attacker")
        try #expect(Keyword.mana.rulesText == "Mana is used to cast spells")
        try #expect(Keyword.gold.rulesText == "Gold is currency for shops and upgrades")
        try #expect(
            Keyword.deathsDoor.rulesText
                == "Death's Door survives a fatal blow at 1 HP — heal before it ends or the next fatal hit kills"
        )
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

    @Test func statusAliases() throws {
        try #expect(Keyword.freeze.statusAlias == "Frozen")
        try #expect(Keyword.stun.statusAlias == "Stunned")
        try #expect(Keyword.burn.statusAlias == "Burning")
        try #expect(Keyword.poison.statusAlias == "Poisoned")
        try #expect(Keyword.bleed.statusAlias == "Bleeding")
    }

    @Test func categoryAllCases() throws {
        let expected: Set = ["Damage Type", "Mitigation", "Restoration", "Resource"]
        let actual = Set(Keyword.Category.allCases.map(\.rawValue))
        try #expect(expected == actual)
    }
}
