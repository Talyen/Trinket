import Testing
import TrinketContent
import TrinketCore
@testable import TrinketFeatureSupport

struct KeywordShineBorderTests {
    @Test func talentNodeReferencedKeywordsExtraction() {
        let node = TalentNode(
            id: "knight_holy_t1_1",
            name: "Oathbound",
            keyword: .holy,
            symbolName: "shield.fill",
            tier: 1,
            description: "Gain 1 Block when you deal Stun or Holy damage."
        )

        var keywords = [node.keyword]
        for referenced in Keyword.referenced(in: node.description) where !keywords.contains(referenced) {
            keywords.append(referenced)
        }

        #expect(keywords.contains(.holy))
        #expect(keywords.contains(.block))
        #expect(keywords.contains(.stun))
        #expect(!keywords.contains(.poison))
    }

    @Test func abilityKeywordsFallback() {
        let physicalAbility = Ability(
            id: "strike",
            name: "Strike",
            tier: .basic,
            directDamage: 5,
            damageKeyword: .physical
        )
        #expect(physicalAbility.keywords.contains(.physical))
    }
}
