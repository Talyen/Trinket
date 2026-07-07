import Testing
import TrinketCore

@Suite struct KeywordCoreTests {
    @Test func allKeywordsAreCovered() {
        let expected: Set = [
            "Physical", "Burn", "Stun", "Block", "Armor", "Health", "Gold", "Holy", "Poison",
            "Bleed", "Leech", "Nature", "Freeze", "Dodge", "Purge", "Mana", "Death's Door",
        ]
        let actual = Set(Keyword.allCases.map(\.rawValue))
        #expect(expected == actual)
    }

    @Test(arguments: Keyword.allCases)
    func allKeywordsHaveRulesText(keyword: Keyword) {
        #expect(!keyword.rulesText.isEmpty, "\(keyword.rawValue) should have rules text")
    }

    @Test(arguments: Keyword.allCases)
    func allKeywordsHaveCategory(keyword: Keyword) {
        #expect(!keyword.category.rawValue.isEmpty, "\(keyword.rawValue) should have a category")
    }

    @Test(arguments: [Keyword.physical, .burn, .poison, .bleed, .holy, .nature, .freeze, .stun])
    func damageTypeCategory(keyword: Keyword) {
        #expect(keyword.category == .damageType, "\(keyword.rawValue) should be damageType")
    }

    @Test(arguments: [Keyword.block, .armor, .dodge, .purge])
    func mitigationCategory(keyword: Keyword) {
        #expect(keyword.category == .mitigation, "\(keyword.rawValue) should be mitigation")
    }

    @Test(arguments: [Keyword.health, .leech, .deathsDoor])
    func restorationCategory(keyword: Keyword) {
        #expect(keyword.category == .restoration, "\(keyword.rawValue) should be restoration")
    }

    @Test(arguments: [Keyword.gold, .mana])
    func resourceCategory(keyword: Keyword) {
        #expect(keyword.category == .resource, "\(keyword.rawValue) should be resource")
    }

    @Test func statusAliases() {
        #expect(Keyword.freeze.statusAlias == "Frozen")
        #expect(Keyword.stun.statusAlias == "Stunned")
        #expect(Keyword.burn.statusAlias == "Burning")
        #expect(Keyword.poison.statusAlias == "Poisoned")
        #expect(Keyword.bleed.statusAlias == "Bleeding")
    }

    @Test func categoryAllCases() {
        let expected: Set = ["Damage Type", "Mitigation", "Restoration", "Resource"]
        let actual = Set(Keyword.Category.allCases.map(\.rawValue))
        #expect(expected == actual)
    }
}
