import Testing
import TrinketContent
import TrinketCore

struct CombatantEquipmentTests {
    @Test func companionSlotsAcceptAccessoryAndTrinketsButNotArmorOrWeapons() throws {
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
        let ring = try ItemFixtures.makeItem("ruby_ring", id: "ring-a")
        let armor = try ItemFixtures.makeItem("leather_armor", id: "armor-a")
        let sword = try ItemFixtures.makeItem("longsword", id: "sword-a")
        let trinketBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .trinket })
        let trinket = try ItemFixtures.makeItem(trinketBase.id, rarity: .astral)
        let loadout = EquipmentLoadout(itemIDsBySlot: [
            .accessory: ring.id,
            .trinket: trinket.id,
            .armor: armor.id,
            .weapon: sword.id,
        ])

        let sanitized = loadout.sanitized(for: bear, inventory: [ring, trinket, armor, sword])

        try #expect(sanitized.itemID(for: .accessory) == ring.id)
        try #expect(sanitized.itemID(for: .trinket) == trinket.id)
        try #expect(sanitized.itemID(for: .secondaryTrinket) == nil)
        try #expect(sanitized.itemID(for: .armor) == nil)
        try #expect(sanitized.itemID(for: .weapon) == nil)
    }

    @Test func companionCannotEquipDuplicateTrinketBase() throws {
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
        let trinketBases = GameContent.itemBaseTypes.filter { $0.slot == .trinket }
        let firstBase = try #require(trinketBases.first)
        let secondBase = try #require(trinketBases.dropFirst().first)
        let charmA = try ItemFixtures.makeItem(firstBase.id, id: "charm-a")
        let charmACopy = try ItemFixtures.makeItem(firstBase.id, id: "charm-a-copy")
        let charmOther = try ItemFixtures.makeItem(secondBase.id, id: "charm-other")
        let inventory = [charmA, charmACopy, charmOther]

        let sanitized = EquipmentLoadout(itemIDsBySlot: [
            .trinket: "charm-a",
            .secondaryTrinket: "charm-a-copy",
        ]).sanitized(for: bear, inventory: inventory)
        try #expect(sanitized.itemID(for: .trinket) == "charm-a")
        try #expect(sanitized.itemID(for: .secondaryTrinket) == nil)

        var loadout = EquipmentLoadout()
        loadout.equip(charmA, in: .trinket, inventory: inventory)
        try #expect(!loadout.canEquip(charmACopy, in: .secondaryTrinket, inventory: inventory))
        try #expect(loadout.canEquip(charmOther, in: .secondaryTrinket, inventory: inventory))

        loadout.equip(charmA, in: .secondaryTrinket, inventory: inventory)
        try #expect(loadout.itemID(for: .trinket) == nil)
        try #expect(loadout.itemID(for: .secondaryTrinket) == "charm-a")
    }

    @Test func sanitizedDropsDuplicateItemAcrossAccessorySlots() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let ring = try ItemFixtures.makeItem("ruby_ring", id: "ring-a", rarity: .basic)
        let loadout = EquipmentLoadout(itemIDsBySlot: [
            .accessory: ring.id,
            .secondaryAccessory: ring.id,
        ])

        let sanitized = loadout.sanitized(for: knight, inventory: [ring])

        try #expect(sanitized.itemID(for: .accessory) == ring.id)
        try #expect(sanitized.itemID(for: .secondaryAccessory) == nil)
    }

    @Test func equipMovesItemBetweenHeroAccessorySlots() throws {
        let ring = try ItemFixtures.makeItem("ruby_ring", id: "ring-a", rarity: .basic)
        var loadout = EquipmentLoadout()
        loadout.equip(ring, in: .accessory, inventory: [ring])
        loadout.equip(ring, in: .secondaryAccessory, inventory: [ring])

        try #expect(loadout.itemID(for: .accessory) == nil)
        try #expect(loadout.itemID(for: .secondaryAccessory) == ring.id)
    }

    @Test func heroSecondarySlotsAcceptFamilyItems() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let sword = try ItemFixtures.makeItem("longsword", id: "sword-a")
        let shield = try ItemFixtures.makeItem("kite_shield", id: "shield-a")
        let ring = try ItemFixtures.makeItem("ruby_ring", id: "ring-a")

        let sanitized = EquipmentLoadout(itemIDsBySlot: [
            .weapon: "sword-a",
            .secondaryWeapon: "shield-a",
            .secondaryAccessory: "ring-a",
        ]).sanitized(for: knight, inventory: [sword, shield, ring])

        try #expect(sanitized.itemID(for: .weapon) == "sword-a")
        try #expect(sanitized.itemID(for: .secondaryWeapon) == "shield-a")
        try #expect(sanitized.itemID(for: .secondaryAccessory) == "ring-a")
    }

    @Test func offHandsOnlyEquipInSecondaryWeaponSlot() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let shieldA = try ItemFixtures.makeItem("kite_shield", id: "shield-a", rarity: .basic)
        let shieldB = try ItemFixtures.makeItem("kite_shield", id: "shield-b")

        let sanitized = EquipmentLoadout(itemIDsBySlot: [
            .weapon: "shield-a",
            .secondaryWeapon: "shield-b",
        ]).sanitized(for: knight, inventory: [shieldA, shieldB])

        try #expect(sanitized.itemID(for: .weapon) == nil)
        try #expect(sanitized.itemID(for: .secondaryWeapon) == "shield-b")
    }

    @Test func twoHandedWeaponUnequipsAndDisablesSecondaryWeaponSlot() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let maul = try ItemFixtures.makeItem("maul", id: "maul-a")
        let sword = try ItemFixtures.makeItem("longsword", id: "sword-a")
        let inventory = [maul, sword]
        var loadout = EquipmentLoadout()
        loadout.equip(sword, in: .secondaryWeapon, inventory: inventory)
        loadout.equip(maul, in: .weapon, inventory: inventory)

        try #expect(loadout.itemID(for: .weapon) == maul.id)
        try #expect(loadout.itemID(for: .secondaryWeapon) == nil)
        try #expect(!loadout.isAvailable(.secondaryWeapon, inventory: inventory))
        try #expect(!loadout.canEquip(sword, in: .secondaryWeapon, inventory: inventory))

        let sanitized = EquipmentLoadout(itemIDsBySlot: [
            .weapon: maul.id,
            .secondaryWeapon: sword.id,
        ]).sanitized(for: knight, inventory: [maul, sword])

        try #expect(sanitized.itemID(for: .weapon) == maul.id)
        try #expect(sanitized.itemID(for: .secondaryWeapon) == nil)
    }

    @Test func rangedTwoHanderAllowsQuiverButBlocksShields() throws {
        let crossbow = try ItemFixtures.makeItem("crossbow", id: "crossbow-a")
        let quiver = try ItemFixtures.makeItem("quiver", id: "quiver-a")
        let shield = try ItemFixtures.makeItem("kite_shield", id: "shield-a")
        let buckler = try ItemFixtures.makeItem("leather_buckler", id: "buckler-a")
        let spellbook = try ItemFixtures.makeItem("spellbook", id: "spellbook-a")
        let sword = try ItemFixtures.makeItem("longsword", id: "sword-a")
        var loadout = EquipmentLoadout()
        loadout.equip(crossbow, in: .weapon, inventory: [crossbow, quiver, shield, buckler, spellbook, sword])

        try #expect(loadout.isAvailable(.secondaryWeapon, inventory: [crossbow, quiver, shield, buckler, spellbook, sword]))
        try #expect(loadout.canEquip(quiver, in: .secondaryWeapon, inventory: [crossbow, quiver, shield, buckler, spellbook, sword]))
        try #expect(!loadout.canEquip(shield, in: .secondaryWeapon, inventory: [crossbow, quiver, shield, buckler, spellbook, sword]))
        try #expect(!loadout.canEquip(buckler, in: .secondaryWeapon, inventory: [crossbow, quiver, shield, buckler, spellbook, sword]))
        try #expect(!loadout.canEquip(spellbook, in: .secondaryWeapon, inventory: [crossbow, quiver, shield, buckler, spellbook, sword]))

        loadout.equip(quiver, in: .secondaryWeapon, inventory: [crossbow, quiver, shield, buckler, spellbook, sword])
        try #expect(loadout.itemID(for: .secondaryWeapon) == quiver.id)
        let longbow = try ItemFixtures.makeItem("longbow", id: "longbow-a")
        var loadout2 = EquipmentLoadout(itemIDsBySlot: [.weapon: crossbow.id, .secondaryWeapon: quiver.id])
        loadout2.equip(longbow, in: .weapon, inventory: [crossbow, longbow, quiver])
        try #expect(loadout2.itemID(for: .secondaryWeapon) == quiver.id)
        var loadout3 = EquipmentLoadout(itemIDsBySlot: [.weapon: crossbow.id, .secondaryWeapon: quiver.id])
        let maul = try ItemFixtures.makeItem("maul", id: "maul-a")
        loadout3.equip(maul, in: .weapon, inventory: [crossbow, maul, quiver])
        try #expect(loadout3.itemID(for: .weapon) == crossbow.id)
        try #expect(loadout3.itemID(for: .secondaryWeapon) == quiver.id)
        loadout3.unequip(.secondaryWeapon)
        loadout3.equip(maul, in: .weapon, inventory: [maul, quiver])
        try #expect(loadout3.itemID(for: .weapon) == maul.id)
        try #expect(loadout3.itemID(for: .secondaryWeapon) == nil)
    }

    @Test func quiverRequiresRangedPrimaryAndBlocksMeleeMainHand() throws {
        let quiver = try ItemFixtures.makeItem("quiver", id: "quiver-a")
        let crossbow = try ItemFixtures.makeItem("crossbow", id: "crossbow-a")
        let sword = try ItemFixtures.makeItem("longsword", id: "sword-a")
        var loadout = EquipmentLoadout()
        try #expect(!loadout.canEquip(quiver, in: .secondaryWeapon, inventory: [quiver, crossbow]))
        loadout.equip(sword, in: .weapon, inventory: [sword, quiver])
        try #expect(!loadout.canEquip(quiver, in: .secondaryWeapon, inventory: [sword, quiver]))
        loadout.equip(crossbow, in: .weapon, inventory: [crossbow, quiver, sword])
        try #expect(loadout.canEquip(quiver, in: .secondaryWeapon, inventory: [crossbow, quiver, sword]))
        loadout.equip(quiver, in: .secondaryWeapon, inventory: [crossbow, quiver, sword])
        try #expect(loadout.itemID(for: .secondaryWeapon) == quiver.id)
        try #expect(!loadout.canEquip(sword, in: .weapon, inventory: [crossbow, quiver, sword]))
    }

    @Test func oneHandedItemsMoveOrDualWieldAcrossWeaponSlots() throws {
        let swordA = try ItemFixtures.makeItem("longsword", id: "sword-a", rarity: .basic)
        let swordB = try ItemFixtures.makeItem("longsword", id: "sword-b")
        let inventory = [swordA, swordB]
        var loadout = EquipmentLoadout()
        loadout.equip(swordA, in: .weapon, inventory: inventory)
        loadout.equip(swordA, in: .secondaryWeapon, inventory: inventory)

        try #expect(loadout.itemID(for: .weapon) == nil)
        try #expect(loadout.itemID(for: .secondaryWeapon) == swordA.id)

        loadout.equip(swordB, in: .weapon, inventory: inventory)

        try #expect(loadout.itemID(for: .weapon) == swordB.id)
        try #expect(loadout.itemID(for: .secondaryWeapon) == swordA.id)
    }

    @Test func itemIDsInFamilyCollectsSiblingSlots() throws {
        let loadout = EquipmentLoadout(itemIDsBySlot: [
            .weapon: "sword-a",
            .secondaryWeapon: "shield-a",
            .armor: "plate-a",
            .accessory: "ring-a",
            .secondaryAccessory: "amulet-a",
            .trinket: "charm-a",
            .secondaryTrinket: "charm-b",
        ])

        try #expect(loadout.itemIDs(inFamilyOf: .weapon) == ["sword-a", "shield-a"])
        try #expect(loadout.itemIDs(inFamilyOf: .secondaryWeapon) == ["sword-a", "shield-a"])
        try #expect(loadout.itemIDs(inFamilyOf: .armor) == ["plate-a"])
        try #expect(loadout.itemIDs(inFamilyOf: .accessory) == ["ring-a", "amulet-a"])
        try #expect(loadout.itemIDs(inFamilyOf: .secondaryAccessory) == ["ring-a", "amulet-a"])
        try #expect(loadout.itemIDs(inFamilyOf: .trinket) == ["charm-a", "charm-b"])
        try #expect(loadout.itemIDs(inFamilyOf: .secondaryTrinket) == ["charm-a", "charm-b"])
    }
}
