import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

struct CombatantEquipmentTests {
    @Test func `companion slots accept accessory and trinkets but not armor or weapons`() throws {
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
        let ring = try ItemFixtures.makeBareItem("ruby_ring", id: "ring-a")
        let armor = try ItemFixtures.makeBareItem("leather_armor", id: "armor-a")
        let sword = try ItemFixtures.makeBareItem("longsword", id: "sword-a")
        let trinketBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .trinket })
        let trinket = try ItemFixtures.makeBareItem(trinketBase.id, rarity: .astral)
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

    @Test func `companion cannot equip duplicate trinket base`() throws {
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
        let trinketBases = GameContent.itemBaseTypes.filter { $0.slot == .trinket }
        let firstBase = try #require(trinketBases.first)
        let secondBase = try #require(trinketBases.dropFirst().first)
        let charmA = try ItemFixtures.makeBareItem(firstBase.id, id: "charm-a")
        let charmACopy = try ItemFixtures.makeBareItem(firstBase.id, id: "charm-a-copy")
        let charmOther = try ItemFixtures.makeBareItem(secondBase.id, id: "charm-other")
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
        #expect(loadout.equippableItems(in: .secondaryTrinket, inventory: inventory) == [charmA, charmOther])

        loadout.equip(charmA, in: .secondaryTrinket, inventory: inventory)
        try #expect(loadout.itemID(for: .trinket) == nil)
        try #expect(loadout.itemID(for: .secondaryTrinket) == "charm-a")
        #expect(loadout.canEquip(charmACopy, in: .secondaryTrinket, inventory: inventory))
        loadout.equip(charmACopy, in: .secondaryTrinket, inventory: inventory)
        #expect(loadout.itemID(for: .secondaryTrinket) == charmACopy.id)
        #expect(!loadout.canEquip(charmA, in: .trinket, inventory: inventory))
        #expect(loadout.equippableItems(in: .trinket, inventory: inventory) == [charmACopy, charmOther])
    }

    @Test func `sanitized drops duplicate item across accessory slots`() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let ring = try ItemFixtures.makeBareItem("ruby_ring", id: "ring-a", rarity: .basic)
        let loadout = EquipmentLoadout(itemIDsBySlot: [
            .accessory: ring.id,
            .secondaryAccessory: ring.id,
        ])

        let sanitized = loadout.sanitized(for: knight, inventory: [ring])

        try #expect(sanitized.itemID(for: .accessory) == ring.id)
        try #expect(sanitized.itemID(for: .secondaryAccessory) == nil)
    }

    @Test func `equip moves item between hero accessory slots`() throws {
        let ring = try ItemFixtures.makeBareItem("ruby_ring", id: "ring-a", rarity: .basic)
        var loadout = EquipmentLoadout()
        loadout.equip(ring, in: .accessory, inventory: [ring])
        loadout.equip(ring, in: .secondaryAccessory, inventory: [ring])

        try #expect(loadout.itemID(for: .accessory) == nil)
        try #expect(loadout.itemID(for: .secondaryAccessory) == ring.id)
    }

    @Test func `hero secondary slots accept family items`() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let sword = try ItemFixtures.makeBareItem("longsword", id: "sword-a")
        let shield = try ItemFixtures.makeBareItem("kite_shield", id: "shield-a")
        let ring = try ItemFixtures.makeBareItem("ruby_ring", id: "ring-a")

        let sanitized = EquipmentLoadout(itemIDsBySlot: [
            .weapon: "sword-a",
            .secondaryWeapon: "shield-a",
            .secondaryAccessory: "ring-a",
        ]).sanitized(for: knight, inventory: [sword, shield, ring])

        try #expect(sanitized.itemID(for: .weapon) == "sword-a")
        try #expect(sanitized.itemID(for: .secondaryWeapon) == "shield-a")
        try #expect(sanitized.itemID(for: .secondaryAccessory) == "ring-a")
    }

    @Test func `off hands only equip in secondary weapon slot`() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let shieldA = try ItemFixtures.makeBareItem("kite_shield", id: "shield-a", rarity: .basic)
        let shieldB = try ItemFixtures.makeBareItem("kite_shield", id: "shield-b")

        let sanitized = EquipmentLoadout(itemIDsBySlot: [
            .weapon: "shield-a",
            .secondaryWeapon: "shield-b",
        ]).sanitized(for: knight, inventory: [shieldA, shieldB])

        try #expect(sanitized.itemID(for: .weapon) == nil)
        try #expect(sanitized.itemID(for: .secondaryWeapon) == "shield-b")
    }

    @Test func `two handed weapon unequips and disables secondary weapon slot`() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let maul = try ItemFixtures.makeBareItem("maul", id: "maul-a")
        let sword = try ItemFixtures.makeBareItem("longsword", id: "sword-a")
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

    @Test func `quiver requires ranged primary and excludes other offhands`() throws {
        let crossbow = try ItemFixtures.makeBareItem("crossbow", id: "crossbow-a")
        let quiver = try ItemFixtures.makeBareItem("quiver", id: "quiver-a")
        let shield = try ItemFixtures.makeBareItem("kite_shield", id: "shield-a")
        let buckler = try ItemFixtures.makeBareItem("leather_buckler", id: "buckler-a")
        let spellbook = try ItemFixtures.makeBareItem("spellbook", id: "spellbook-a")
        let sword = try ItemFixtures.makeBareItem("longsword", id: "sword-a")
        let inventory = [crossbow, quiver, shield, buckler, spellbook, sword]
        var loadout = EquipmentLoadout()
        #expect(loadout.isAvailable(.secondaryWeapon, inventory: inventory))
        #expect(loadout.equippableItems(in: .secondaryWeapon, inventory: inventory) == [shield, buckler, spellbook, sword])

        loadout.equip(sword, in: .weapon, inventory: inventory)
        #expect(!loadout.canEquip(quiver, in: .secondaryWeapon, inventory: inventory))
        loadout.equip(shield, in: .secondaryWeapon, inventory: inventory)
        #expect(loadout.itemID(for: .secondaryWeapon) == shield.id)
        loadout.equip(crossbow, in: .weapon, inventory: inventory)
        #expect(loadout.itemID(for: .weapon) == crossbow.id)
        #expect(loadout.itemID(for: .secondaryWeapon) == nil)
        #expect(loadout.isAvailable(.secondaryWeapon, inventory: inventory))
        #expect(loadout.equippableItems(in: .secondaryWeapon, inventory: inventory) == [quiver])
        loadout.equip(quiver, in: .secondaryWeapon, inventory: inventory)
        #expect(loadout.itemID(for: .secondaryWeapon) == quiver.id)
    }

    @Test func `equipped quiver survives ranged replacement and blocks melee replacement`() throws {
        let quiver = try ItemFixtures.makeBareItem("quiver", id: "quiver-a")
        let crossbow = try ItemFixtures.makeBareItem("crossbow", id: "crossbow-a")
        let longbow = try ItemFixtures.makeBareItem("longbow", id: "longbow-a")
        let sword = try ItemFixtures.makeBareItem("longsword", id: "sword-a")
        let maul = try ItemFixtures.makeBareItem("maul", id: "maul-a")
        let inventory = [crossbow, longbow, quiver, sword, maul]
        var loadout = EquipmentLoadout(itemIDsBySlot: [.weapon: crossbow.id, .secondaryWeapon: quiver.id])
        loadout.equip(longbow, in: .weapon, inventory: inventory)
        #expect(loadout.itemID(for: .weapon) == longbow.id)
        #expect(loadout.itemID(for: .secondaryWeapon) == quiver.id)
        let rangedLoadout = loadout
        for melee in [sword, maul] {
            #expect(!loadout.canEquip(melee, in: .weapon, inventory: inventory))
            loadout.equip(melee, in: .weapon, inventory: inventory)
            #expect(loadout == rangedLoadout)
        }
        loadout.unequip(.secondaryWeapon)
        loadout.equip(maul, in: .weapon, inventory: inventory)
        #expect(loadout.itemID(for: .weapon) == maul.id)
        #expect(loadout.itemID(for: .secondaryWeapon) == nil)
    }

    @Test func `one handed items move or dual wield across weapon slots`() throws {
        let swordA = try ItemFixtures.makeBareItem("longsword", id: "sword-a", rarity: .basic)
        let swordB = try ItemFixtures.makeBareItem("longsword", id: "sword-b")
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

    @Test func `sanitized handles duplicate inventory item IDs without trapping`() throws {
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
        let ring = try ItemFixtures.makeBareItem("ruby_ring", id: "ring-a")
        let duplicateRing = try ItemFixtures.makeBareItem("ruby_ring", id: "ring-a")
        let loadout = EquipmentLoadout(itemIDsBySlot: [.accessory: ring.id])

        let sanitized = loadout.sanitized(for: bear, inventory: [ring, duplicateRing])
        try #expect(sanitized.itemID(for: .accessory) == ring.id)
    }
}
