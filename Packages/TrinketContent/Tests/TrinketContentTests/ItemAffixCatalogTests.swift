import Testing
import TrinketContent

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

    @Test func itemAffixesDoNotGrantPrimaryStats() {
        for definition in GameContent.itemAffixDefinitions {
            for power in [definition.basic, definition.astral] {
                for modifier in power.modifiers {
                    switch modifier {
                    case .strength, .agility, .toughness, .intellect, .wisdom:
                        Issue.record("\(definition.id) grants primary stats via \(modifier)")
                    default:
                        break
                    }
                }
            }
        }
    }

    @Test func eachAffixDefinesBasicAndAstralPowers() throws {
        for definition in GameContent.itemAffixDefinitions {
            try #expect(!definition.basic.description.isEmpty, "\(definition.id)) basic description")
            try #expect(!definition.astral.description.isEmpty, "\(definition.id)) astral description")
            try #expect(
                !definition.basic.modifiers.isEmpty || definition.basic.triggers != CombatTraitTriggers(),
                "\(definition.id)) basic power"
            )
            try #expect(
                !definition.astral.modifiers.isEmpty || definition.astral.triggers != CombatTraitTriggers(),
                "\(definition.id)) astral power"
            )
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

    @Test func revisedAffixesUseConsistentLeechWording() throws {
        let byID = Dictionary(uniqueKeysWithValues: GameContent.itemAffixDefinitions.map { ($0.id, $0) })

        let bloodstone = try #require(byID["bloodstone"])
        try #expect(bloodstone.basic.description == "Increase Leech healing by 1")
        try #expect(bloodstone.basic.modifiers == [.leechHealing(1)])

        let lifeweave = try #require(byID["lifeweave"])
        try #expect(lifeweave.basic.description == "Increase Leech healing by 1")
        try #expect(lifeweave.basic.modifiers == [.leechHealing(1)])
    }

    @Test func thinKeywordAffixesUseExpectedCopy() throws {
        let byID = Dictionary(uniqueKeysWithValues: GameContent.itemAffixDefinitions.map { ($0.id, $0) })

        let knockout = try #require(byID["knockout"])
        try #expect(knockout.basic.description == "Deal 3 Physical damage when you Stun an enemy")

        let shredding = try #require(byID["shredding"])
        try #expect(shredding.basic.description == "Ignore 10% of enemy mitigation")

        let absolving = try #require(byID["absolving"])
        try #expect(absolving.basic.description == "Cleanse 1 status effect when you deal Holy damage")

        let retaliatory = try #require(byID["retaliatory"])
        try #expect(retaliatory.basic.description == "Reflect 10% of damage taken")

        let riposte = try #require(byID["riposte"])
        try #expect(riposte.keywords == [.physical, .dodge])
    }
}
