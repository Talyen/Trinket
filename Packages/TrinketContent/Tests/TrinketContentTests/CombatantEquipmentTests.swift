import Testing
import TrinketContent
import TrinketCore

struct CombatantEquipmentTests {
    @Test(arguments: [
        (Combatant.Role.hero, [EquipmentSlot.weapon, .armor, .trinket]),
        (.companion, [.trinket, .armor, .secondaryTrinket])
    ])
    func roleEquipmentSlotsMatchAuthoredLoadout(
        role: Combatant.Role,
        expectedSlots: [EquipmentSlot]
    ) throws {
        try #expect(role.equipmentSlots == expectedSlots)
    }

    @Test func secondaryTrinketSlotAcceptsTrinketItems() throws {
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
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

        try #expect(sanitized.itemID(for: .trinket) == "ring-a")
        try #expect(sanitized.itemID(for: .secondaryTrinket) == "ring-a")
        try #expect(sanitized.itemID(for: .weapon) == nil)
    }
}
