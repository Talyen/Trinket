import XCTest
import TrinketContent
import TrinketCore

final class ThemedGearGeneratorTests: XCTestCase {
    func testGeneratesFixedAffixCountPerSlot() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        var rng = SeededRandomNumberGenerator(seed: 99)
        let generator = ThemedGearGenerator()

        let build = generator.generate(
            for: knight,
            rarity: .basic,
            fixedAffixCount: 1,
            idPrefix: "themed",
            using: &rng
        )

        XCTAssertEqual(build.inventory.count, knight.role.equipmentSlots.count)
        XCTAssertTrue(build.inventory.allSatisfy { $0.affixes.count == 1 })
        XCTAssertEqual(build.loadout.itemIDsBySlot.count, knight.role.equipmentSlots.count)
    }

    func testKeywordProfileIncludesAbilityKeywords() throws {
        let wizard = try XCTUnwrap(GameContent.heroes.first { $0.id == "wizard" })
        XCTAssertTrue(wizard.keywordProfile.contains(.burn))
    }

    func testFixedAffixCountOverrideInItemGenerator() throws {
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        var rng = SeededRandomNumberGenerator(seed: 12)

        let item = ItemGenerator().generate(
            id: "fixed",
            baseType: baseType,
            rarity: .basic,
            fixedAffixCount: 1,
            keywordBias: [.physical],
            using: &rng
        )

        XCTAssertEqual(item.affixes.count, 1)
    }
}
