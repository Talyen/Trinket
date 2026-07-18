import Testing
import TrinketCore

struct KeywordCoreTests {
    @Test func allKeywordsAreCovered() throws {
        let expected: Set = [
            "Physical", "Burn", "Stun", "Block", "Armor", "Health", "Gold", "Holy", "Poison",
            "Bleed", "Leech", "Freeze", "Dodge", "Purge", "Mana", "Death's Door"
        ]
        let actual = Set(Keyword.allCases.map(\.rawValue))
        try #expect(expected == actual)
    }

    @Test(arguments: Keyword.allCases)
    func allKeywordsHaveRulesTextAndCategory(keyword: Keyword) throws {
        try #expect(!keyword.rulesText.isEmpty, "\(keyword.rawValue) should have rules text")
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
        (.armor, .mitigation),
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
