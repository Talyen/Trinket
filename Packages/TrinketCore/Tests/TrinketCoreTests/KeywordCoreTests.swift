import Testing
import TrinketCore

struct KeywordCoreTests {
    @Test func allKeywordsAreCovered() throws {
        let expected: Set = [
            "Physical", "Burn", "Stun", "Block", "Armor", "Health", "Gold", "Holy", "Poison",
            "Bleed", "Leech", "Nature", "Freeze", "Dodge", "Purge", "Mana", "Death's Door"
        ]
        let actual = Set(Keyword.allCases.map(\.rawValue))
        try #expect(expected == actual)
    }

    @Test(arguments: Keyword.allCases)
    func allKeywordsHaveRulesText(keyword: Keyword) throws {
        try #expect(!keyword.rulesText.isEmpty, "\(keyword.rawValue) should have rules text")
    }

    @Test(arguments: Keyword.allCases)
    func allKeywordsHaveCategory(keyword: Keyword) throws {
        try #expect(!keyword.category.rawValue.isEmpty, "\(keyword.rawValue) should have a category")
    }

    @Test(arguments: [Keyword.physical, .burn, .poison, .bleed, .holy, .nature, .freeze, .stun])
    func damageTypeCategory(keyword: Keyword) throws {
        try #expect(keyword.category == .damageType, "\(keyword.rawValue) should be damageType")
    }

    @Test(arguments: [Keyword.block, .armor, .dodge, .purge])
    func mitigationCategory(keyword: Keyword) throws {
        try #expect(keyword.category == .mitigation, "\(keyword.rawValue) should be mitigation")
    }

    @Test(arguments: [Keyword.health, .leech, .deathsDoor])
    func restorationCategory(keyword: Keyword) throws {
        try #expect(keyword.category == .restoration, "\(keyword.rawValue) should be restoration")
    }

    @Test(arguments: [Keyword.gold, .mana])
    func resourceCategory(keyword: Keyword) throws {
        try #expect(keyword.category == .resource, "\(keyword.rawValue) should be resource")
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
