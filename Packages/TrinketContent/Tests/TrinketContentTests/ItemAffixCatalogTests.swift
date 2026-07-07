import Testing
import TrinketContent

@Suite
struct ItemAffixCatalogTests {
    @Test func affixIDsAreUnique() {
        let ids = GameContent.itemAffixDefinitions.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func eachAffixHasPositiveWeightAndKeywords() {
        for definition in GameContent.itemAffixDefinitions {
            #expect(definition.weight > 0, "\(definition.id) should have positive weight")
            #expect(!definition.keywords.isEmpty, "\(definition.id)) should declare keywords")
        }
    }

    @Test func eachAffixDefinesBasicAndAstralPowers() {
        for definition in GameContent.itemAffixDefinitions {
            #expect(!definition.basic.description.isEmpty, "\(definition.id)) basic description")
            #expect(!definition.astral.description.isEmpty, "\(definition.id)) astral description")
            #expect(!definition.basic.modifiers.isEmpty, "\(definition.id)) basic modifiers")
            #expect(!definition.astral.modifiers.isEmpty, "\(definition.id)) astral modifiers")
        }
    }

    @Test func eachItemBaseTypeHasEligibleAffixPool() {
        for baseType in GameContent.itemBaseTypes {
            let eligible = GameContent.itemAffixDefinitions.filter { definition in
                definition.slot == baseType.slot &&
                    !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
            }
            #expect(!eligible.isEmpty, "\(baseType.id)) should have at least one eligible affix")
        }
    }
}
