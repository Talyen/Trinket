import Testing
import TrinketContent
import TrinketCore

struct ThemedGearGeneratorTests {
    @Test func generatesFixedAffixCountPerSlot() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        var rng = SeededRandomNumberGenerator(seed: 99)
        let generator = ThemedGearGenerator()

        let build = generator.generate(
            for: knight,
            rarity: .basic,
            fixedAffixCount: 1,
            idPrefix: "themed",
            using: &rng
        )

        let primaryID = try #require(build.loadout.itemID(for: .weapon))
        let primary = try #require(build.inventory.first { $0.id == primaryID })
        let expectedCount = knight.role.equipmentSlots.count
            - (primary.baseType.weaponKind == .twoHanded ? 1 : 0)

        try #expect(build.inventory.count == expectedCount)
        try #expect(build.inventory.allSatisfy { $0.affixes.count == 1 })
        try #expect(build.loadout.itemIDsBySlot.count == expectedCount)
        try #expect(build.loadout.isAvailable(.secondaryWeapon, inventory: build.inventory)
            == (primary.baseType.weaponKind != .twoHanded))
    }

    @Test func keywordProfileIncludesAbilityKeywords() throws {
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        try #expect(wizard.keywordProfile.contains(.burn))
    }

    @Test func fixedAffixCountOverrideInItemGenerator() throws {
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        var rng = SeededRandomNumberGenerator(seed: 12)

        let item = ItemGenerator().generate(
            id: "fixed",
            baseType: baseType,
            rarity: .basic,
            fixedAffixCount: 1,
            keywordBias: [.physical],
            using: &rng
        )

        try #expect(item.affixes.count == 1)
    }

    @Test func requireBuildAlignmentRejectsMismatchedDamageAffixes() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let bias = Set(knight.abilityLoadout.abilities.flatMap(\.keywords))
        #expect(!bias.contains(.poison))

        var rng = SeededRandomNumberGenerator(seed: 7)
        let build = ThemedGearGenerator().generate(
            for: knight.withAbilityLoadout(knight.abilityLoadout),
            rarity: .astral,
            fixedAffixCount: 3,
            idPrefix: "aligned",
            keywordBias: bias,
            requireBuildAlignment: true,
            using: &rng
        )

        let definitions = Dictionary(
            uniqueKeysWithValues: GameContent.itemAffixDefinitions.map { ($0.id, $0) }
        )
        for item in build.inventory {
            for affix in item.affixes {
                let definition = try #require(definitions[affix.id])
                try #expect(definition.isAligned(withBuildKeywords: bias))
                let damageKeywords = definition.keywords.filter { $0.category == .damageType }
                try #expect(damageKeywords.isSubset(of: bias))
            }
        }
    }
}
