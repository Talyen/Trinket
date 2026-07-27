import Testing
import TrinketContent
import TrinketCore

struct CombatantEquipmentTests {
    @Test(arguments: [
        (Combatant.Role.hero, [ItemSlot.weapon, .armor, .trinket]),
        (.companion, [.trinket, .armor, .secondaryTrinket]),
    ])
    func roleEquipmentSlotsMatchAuthoredLoadout(
        role: Combatant.Role,
        expectedSlots: [ItemSlot]
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
        let other = InventoryItem(
            id: "ring-b",
            baseType: trinketBase,
            rarity: .basic,
            displayName: "Sapphire Ring",
            affixes: []
        )
        let loadout = EquipmentLoadout(itemIDsBySlot: [
            .trinket: "ring-a",
            .secondaryTrinket: "ring-b",
        ])

        let sanitized = loadout.sanitized(for: bear, inventory: [trinket, other])

        try #expect(sanitized.itemID(for: .trinket) == "ring-a")
        try #expect(sanitized.itemID(for: .secondaryTrinket) == "ring-b")
        try #expect(sanitized.itemID(for: .weapon) == nil)
    }

    @Test func sanitizedDropsDuplicateItemAcrossTrinketSlots() throws {
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
            .secondaryTrinket: "ring-a",
        ])

        let sanitized = loadout.sanitized(for: bear, inventory: [trinket])

        try #expect(sanitized.itemID(for: .trinket) == "ring-a")
        try #expect(sanitized.itemID(for: .secondaryTrinket) == nil)
    }

    @Test func equipMovesItemBetweenCompanionTrinketSlots() throws {
        let trinketBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .trinket })
        let trinket = InventoryItem(
            id: "ring-a",
            baseType: trinketBase,
            rarity: .basic,
            displayName: "Ruby Ring",
            affixes: []
        )
        var loadout = EquipmentLoadout()
        loadout.equip(trinket, in: .trinket)
        loadout.equip(trinket, in: .secondaryTrinket)

        try #expect(loadout.itemID(for: .trinket) == nil)
        try #expect(loadout.itemID(for: .secondaryTrinket) == "ring-a")
    }
}
