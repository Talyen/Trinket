import Testing
import TrinketContent
import TrinketCore

struct CombatantEquipmentTests {
    @Test(arguments: [
        (Combatant.Role.hero, [ItemSlot.weapon, .secondaryWeapon, .armor, .trinket, .secondaryTrinket, .tertiaryTrinket]),
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

    @Test func heroSecondarySlotsAcceptFamilyItems() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let swordBase = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let shieldBase = try #require(GameContent.itemBaseTypes.first { $0.id == "kite_shield" })
        let trinketBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .trinket })
        let sword = InventoryItem(
            id: "sword-a",
            baseType: swordBase,
            rarity: .basic,
            displayName: "Longsword",
            affixes: []
        )
        let shield = InventoryItem(
            id: "shield-a",
            baseType: shieldBase,
            rarity: .basic,
            displayName: "Kite Shield",
            affixes: []
        )
        let ring = InventoryItem(
            id: "ring-a",
            baseType: trinketBase,
            rarity: .basic,
            displayName: "Ruby Ring",
            affixes: []
        )

        let sanitized = EquipmentLoadout(itemIDsBySlot: [
            .weapon: "sword-a",
            .secondaryWeapon: "shield-a",
            .tertiaryTrinket: "ring-a",
        ]).sanitized(for: knight, inventory: [sword, shield, ring])

        try #expect(sanitized.itemID(for: .weapon) == "sword-a")
        try #expect(sanitized.itemID(for: .secondaryWeapon) == "shield-a")
        try #expect(sanitized.itemID(for: .tertiaryTrinket) == "ring-a")
    }

    @Test func twoShieldsEquipAcrossWeaponSlots() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let shieldBase = try #require(GameContent.itemBaseTypes.first { $0.id == "kite_shield" })
        let shieldA = InventoryItem(
            id: "shield-a",
            baseType: shieldBase,
            rarity: .basic,
            displayName: "Kite Shield",
            affixes: []
        )
        let shieldB = InventoryItem(
            id: "shield-b",
            baseType: shieldBase,
            rarity: .basic,
            displayName: "Kite Shield",
            affixes: []
        )

        let sanitized = EquipmentLoadout(itemIDsBySlot: [
            .weapon: "shield-a",
            .secondaryWeapon: "shield-b",
        ]).sanitized(for: knight, inventory: [shieldA, shieldB])

        try #expect(sanitized.itemID(for: .weapon) == "shield-a")
        try #expect(sanitized.itemID(for: .secondaryWeapon) == "shield-b")
    }

    @Test func equipMovesItemBetweenHeroWeaponSlots() throws {
        let swordBase = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let sword = InventoryItem(
            id: "sword-a",
            baseType: swordBase,
            rarity: .basic,
            displayName: "Longsword",
            affixes: []
        )
        var loadout = EquipmentLoadout()
        loadout.equip(sword, in: .weapon)
        loadout.equip(sword, in: .secondaryWeapon)

        try #expect(loadout.itemID(for: .weapon) == nil)
        try #expect(loadout.itemID(for: .secondaryWeapon) == "sword-a")
    }

    @Test func itemIDsInFamilyCollectsSiblingSlots() throws {
        let loadout = EquipmentLoadout(itemIDsBySlot: [
            .weapon: "sword-a",
            .secondaryWeapon: "shield-a",
            .armor: "plate-a",
            .trinket: "ring-a",
        ])

        try #expect(loadout.itemIDs(inFamilyOf: .weapon) == ["sword-a", "shield-a"])
        try #expect(loadout.itemIDs(inFamilyOf: .secondaryWeapon) == ["sword-a", "shield-a"])
        try #expect(loadout.itemIDs(inFamilyOf: .armor) == ["plate-a"])
        try #expect(loadout.itemIDs(inFamilyOf: .trinket) == ["ring-a"])
    }
}
