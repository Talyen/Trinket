import Testing
import TrinketContent
import TrinketCore

@Suite
struct CombatantEquipmentTests {
    @Test func petEquipmentSlotsUseTwoTrinketsAndArmor() {
        #expect(
            Combatant.Role.pet.equipmentSlots == [.trinket, .armor, .secondaryTrinket]
        )
    }

    @Test func heroEquipmentSlotsKeepWeaponArmorTrinket() {
        #expect(
            Combatant.Role.hero.equipmentSlots == [.weapon, .armor, .trinket]
        )
    }

    @Test func secondaryTrinketSlotAcceptsTrinketItems() throws {
        let bear = try #require(GameContent.pets.first { $0.id == "bear" })
        let trinketBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .trinket })
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

        #expect(sanitized.itemID(for: .trinket) == "ring-a")
        #expect(sanitized.itemID(for: .secondaryTrinket) == "ring-a")
        #expect(sanitized.itemID(for: .weapon == nil))
    }
}
