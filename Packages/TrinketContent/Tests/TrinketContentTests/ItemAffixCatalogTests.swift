import Testing
import TrinketContent

@Suite
struct ItemAffixCatalogTests {
    @Test func affixIDsAreUnique() throws {
        let ids = GameContent.itemAffixDefinitions.map(\.id)
        try #expect(Set(ids).count == ids.count)
    }

    @Test func eachAffixHasPositiveWeightAndKeywords() throws {
        for definition in GameContent.itemAffixDefinitions {
            try #expect(definition.weight > 0, "\(definition.id) should have positive weight")
            try #expect(!definition.keywords.isEmpty, "\(definition.id)) should declare keywords")
        }
    }

    @Test func eachAffixDefinesBasicAndAstralPowers() throws {
        for definition in GameContent.itemAffixDefinitions {
            try #expect(!definition.basic.description.isEmpty, "\(definition.id)) basic description")
            try #expect(!definition.astral.description.isEmpty, "\(definition.id)) astral description")
            try #expect(!definition.basic.modifiers.isEmpty, "\(definition.id)) basic modifiers")
            try #expect(!definition.astral.modifiers.isEmpty, "\(definition.id)) astral modifiers")
        }
    }

    @Test func eachItemBaseTypeHasEligibleAffixPool() throws {
        for baseType in GameContent.itemBaseTypes {
            let eligible = GameContent.itemAffixDefinitions.filter { definition in
                definition.slot == baseType.slot &&
                    !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
            }
            try #expect(!eligible.isEmpty, "\(baseType.id)) should have at least one eligible affix")
        }
    }
}
