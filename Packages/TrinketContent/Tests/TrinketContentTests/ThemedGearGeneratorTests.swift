import Testing
import TrinketContent
import TrinketCore

@Suite
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

        #expect(build.inventory.count == knight.role.equipmentSlots.count)
        #expect(build.inventory.allSatisfy { $0.affixes.count == 1 })
        #expect(build.loadout.itemIDsBySlot.count == knight.role.equipmentSlots.count)
    }

    @Test func keywordProfileIncludesAbilityKeywords() throws {
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        #expect(wizard.keywordProfile.contains(.burn))
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

        #expect(item.affixes.count == 1)
    }
}
