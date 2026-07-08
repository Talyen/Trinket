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

    @Test func revisedAffixesUseConsistentLeechAndHybridWording() throws {
        let byID = Dictionary(uniqueKeysWithValues: GameContent.itemAffixDefinitions.map { ($0.id, $0) })

        let bloodstone = try #require(byID["bloodstone"])
        try #expect(bloodstone.basic.description == "Increases Leech healing by 1")
        try #expect(bloodstone.basic.modifiers == [.leechHealing(1)])

        let lifeweave = try #require(byID["lifeweave"])
        try #expect(lifeweave.basic.description == "Increases Leech healing by 1")
        try #expect(lifeweave.basic.modifiers == [.leechHealing(1)])

        let gilded = try #require(byID["gilded"])
        try #expect(gilded.basic.description == "Increases Gold gained by 1 and Stun damage dealt by 1")
        try #expect(gilded.keywords.contains(.gold) && gilded.keywords.contains(.stun))

        let verdant = try #require(byID["verdant"])
        try #expect(verdant.basic.description == "Increases Nature damage dealt by 1 and Health restored by 1")

        let sparkling = try #require(byID["sparkling"])
        try #expect(sparkling.basic.description == "Increases Holy damage dealt by 1 and Block gained by 1")
    }

    @Test func newArchetypeAndUtilityAffixesArePresent() throws {
        let ids = Set(GameContent.itemAffixDefinitions.map(\.id))
        let expected: Set<String> = [
            "venomancers", "cryomancers", "thunderers", "druids",
            "leeching", "sapping", "caustic", "persistent", "scorching",
            "rimed", "insulated", "sanctified", "thorned", "bloodbound",
            "enduring", "plated",
            "siphoning", "manabound", "beastbond", "biting", "noxious",
            "hallowed", "hoarfrost", "stormforged", "vitalis", "ashen",
            "infected", "ashen_wake", "cauterize", "contagion", "shatter",
            "brittle", "executioners", "riposte", "relentless", "cascading",
            "undergird", "ablution", "aftershock", "hexmark", "packbond",
            "symbiosis", "second_wind", "deathgrip", "frostburn",
        ]
        try #expect(expected.isSubset(of: ids))
        try #expect(GameContent.itemAffixDefinitions.count == 89)
    }
}
