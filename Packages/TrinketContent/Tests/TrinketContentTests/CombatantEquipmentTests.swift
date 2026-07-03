import XCTest
import TrinketContent
import TrinketCore

final class CombatantEquipmentTests: XCTestCase {
    func testPetEquipmentSlotsUseTwoTrinketsAndArmor() {
        XCTAssertEqual(
            Combatant.Role.pet.equipmentSlots,
            [.trinket, .armor, .secondaryTrinket]
        )
    }

    func testHeroEquipmentSlotsKeepWeaponArmorTrinket() {
        XCTAssertEqual(
            Combatant.Role.hero.equipmentSlots,
            [.weapon, .armor, .trinket]
        )
    }

    func testSecondaryTrinketSlotAcceptsTrinketItems() throws {
        let bear = try XCTUnwrap(GameContent.pets.first { $0.id == "bear" })
        let trinketBase = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.slot == .trinket })
        let trinket = InventoryItem(
            id: "ring-a",
            baseType: trinketBase,
            rarity: .basic,
            displayName: "Ruby Ring",
            affixes: []
        )
        let loadout = EquipmentLoadout(itemIDsBySlot: [
            .trinket: "ring-a",
            .secondaryTrinket: "ring-a"
        ])

        let sanitized = loadout.sanitized(for: bear, inventory: [trinket])

        XCTAssertEqual(sanitized.itemID(for: .trinket), "ring-a")
        XCTAssertEqual(sanitized.itemID(for: .secondaryTrinket), "ring-a")
        XCTAssertNil(sanitized.itemID(for: .weapon))
    }
}
