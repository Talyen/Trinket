import Testing
import TrinketContent
import TrinketCore

struct SimulationEquipmentPolicyTests {
    @Test func `retains ties and upgrades cannot cycle back to displaced gear`() throws {
        let owner = GameContent.heroes[0]
        let weak = item("weak", slot: .armor, count: 1)
        let equal = item("equal", slot: .armor, count: 1)
        let strong = item("strong", slot: .armor, count: 3)
        let inventory = [weak, equal, strong]
        var loadout = EquipmentLoadout(itemIDsBySlot: [.armor: weak.id])
        #expect(SimulationEquipmentPolicy.nextUpgrade(for: owner, inventory: [weak, equal], loadout: loadout) == nil)
        let upgrade = try #require(SimulationEquipmentPolicy.nextUpgrade(for: owner, inventory: inventory, loadout: loadout))
        #expect(upgrade.itemID == strong.id)
        loadout.equip(strong, in: upgrade.slot, inventory: inventory)
        #expect(SimulationEquipmentPolicy.nextUpgrade(for: owner, inventory: inventory, loadout: loadout) == nil)
    }

    @Test func `fills secondary slots and never steals another combatant's gear`() throws {
        let owner = GameContent.heroes[0]
        let first = item("first", slot: .accessory, count: 1)
        let second = item("second", slot: .accessory, count: 1)
        let reserved = item("reserved", slot: .accessory, count: 4)
        let upgrade = try #require(SimulationEquipmentPolicy.nextUpgrade(
            for: owner, inventory: [reserved, second, first],
            loadout: EquipmentLoadout(itemIDsBySlot: [.accessory: first.id]), reservedItemIDs: [reserved.id],
        ))
        #expect(upgrade.itemID == second.id)
        #expect(upgrade.slot == .secondaryAccessory)
    }

    @Test func `two handed replacement includes the displaced off hand's budget`() {
        let owner = GameContent.heroes[0]
        let first = item("first", slot: .weapon, count: 3, kind: .oneHanded)
        let second = item("second", slot: .weapon, count: 3, kind: .oneHanded)
        let twoHanded = item("two-handed", slot: .weapon, count: 2, kind: .twoHanded)
        #expect(SimulationEquipmentPolicy.nextUpgrade(
            for: owner, inventory: [first, second, twoHanded],
            loadout: EquipmentLoadout(itemIDsBySlot: [.weapon: first.id, .secondaryWeapon: second.id]),
        ) == nil)
    }

    @Test func `resistance remains useful without matching outgoing damage`() throws {
        let owner = try holyKnight()
        let generic = item("generic", slot: .armor, count: 0)
        let resistance = try rolledItem("resistance", affixID: "emberguard", high: true)
        let upgrade = SimulationEquipmentPolicy.nextUpgrade(
            for: owner, inventory: [generic, resistance],
            loadout: EquipmentLoadout(itemIDsBySlot: [.armor: generic.id]),
        )
        #expect(upgrade?.itemID == resistance.id)
    }

    @Test(arguments: ["consecrated", "beacon"])
    func `stronger saved modifier and trigger rolls break budget ties`(affixID: String) throws {
        let owner = try holyKnight()
        let weak = try rolledItem("weak", affixID: affixID, high: false)
        let strong = try rolledItem("strong", affixID: affixID, high: true)
        let filler = item("filler", slot: weak.baseType.slot, count: 4, kind: weak.baseType.weaponKind)
        let secondary: ItemSlot = weak.baseType.slot == .weapon ? .secondaryWeapon : .secondaryAccessory
        var loadout = EquipmentLoadout(itemIDsBySlot: [weak.baseType.slot: weak.id, secondary: filler.id])
        let inventory = [weak, strong, filler]
        let upgrade = try #require(SimulationEquipmentPolicy.nextUpgrade(for: owner, inventory: inventory, loadout: loadout))
        #expect(upgrade.itemID == strong.id)
        loadout.equip(strong, in: upgrade.slot, inventory: inventory)
        #expect(SimulationEquipmentPolicy.nextUpgrade(for: owner, inventory: inventory, loadout: loadout) == nil)
    }

    @Test func `Oathkeeper enables Physical bonus gear across the whole Holy loadout`() throws {
        let owner = try holyKnight()
        let oathkeeper = try #require(GameContent.uniqueItems.first { $0.id == "oathkeeper" })
        let generic = item("generic", slot: .weapon, count: 0, kind: .oneHanded)
        let keen = try rolledItem("keen", affixID: "keen", high: true)
        let gear = [oathkeeper, generic, keen]
        let filler = item("filler", slot: .weapon, count: 4, kind: .oneHanded)
        #expect(SimulationEquipmentPolicy.nextUpgrade(
            for: owner, inventory: [generic, keen, filler],
            loadout: EquipmentLoadout(itemIDsBySlot: [.weapon: generic.id, .secondaryWeapon: filler.id]),
        )?.itemID != keen.id)
        let upgrade = SimulationEquipmentPolicy.nextUpgrade(
            for: owner, inventory: gear,
            loadout: EquipmentLoadout(itemIDsBySlot: [.weapon: oathkeeper.id, .secondaryWeapon: generic.id]),
        )
        #expect(upgrade?.itemID == keen.id)
    }

    @Test func `Mana effects do not require tagged Burn and Freeze damage`() throws {
        let owner = try holyKnight()
        let mana = try rolledItem("mana", affixID: "manabound", high: true)
        let wizard = Combatant(id: "mage", name: "Mage", role: .hero, maxHealth: 10, maxMana: 5, abilities: [AbilityCatalog.smite])
        let accessory = item("accessory", slot: .accessory, count: 0)
        let other = item("other", slot: .accessory, count: 4)
        let slots = EquipmentLoadout(itemIDsBySlot: [.accessory: accessory.id, .secondaryAccessory: other.id])
        #expect(SimulationEquipmentPolicy.nextUpgrade(for: wizard, inventory: [accessory, other, mana], loadout: slots)?.itemID == mana.id)
        #expect(SimulationEquipmentPolicy.nextUpgrade(for: owner, inventory: [accessory, other, mana], loadout: slots) == nil)
    }

    @Test func `better rolls do not order unrelated equal budget effects`() throws {
        let owner = try holyKnight()
        let generic = item("generic", slot: .armor, count: 1)
        let resistance = try rolledItem("resistance", affixID: "emberguard", high: true)
        #expect(SimulationEquipmentPolicy.nextUpgrade(
            for: owner, inventory: [generic, resistance],
            loadout: EquipmentLoadout(itemIDsBySlot: [.armor: generic.id]),
        ) == nil)
    }

    @Test func `mixed rolls cannot trade damage for resistance within one affix`() throws {
        let owner = try holyKnight()
        let definition = try #require(GameContent.itemAffixDefinition(matching: "martyrs"))
        let base = ItemBaseType(id: "armor", name: "Armor", slot: .armor, keywordAffinities: [])
        func armor(_ id: String, damage: Int, resistance: Double) -> InventoryItem {
            InventoryItem(
                id: id,
                baseType: base,
                rarity: .basic,
                displayName: id,
                affixes: [definition.resolved(for: .basic)],
                affixPowers: [ItemAffixPower(
                    description: "", modifiers: [.damageDealt(.holy, damage), .damageTakenPercent(.holy, resistance)],
                )],
            )
        }
        let worn = armor("worn", damage: 1, resistance: 0.12)
        let mixed = armor("mixed", damage: 2, resistance: 0.08)
        #expect(SimulationEquipmentPolicy.nextUpgrade(
            for: owner, inventory: [worn, mixed], loadout: EquipmentLoadout(itemIDsBySlot: [.armor: worn.id]),
        ) == nil)
    }

    @Test(arguments: ["mace", "maul"])
    func `bow and quiver can switch to a stronger legal melee loadout`(baseID: String) throws {
        let owner = try holyKnight()
        let bow = try basedItem("bow", baseID: "shortbow", count: 1)
        let quiver = try basedItem("quiver", baseID: "quiver", count: 1)
        let melee = try basedItem("melee", baseID: baseID, count: 4)
        let reserved = try basedItem("reserved", baseID: baseID, count: 8)
        let inventory = [bow, quiver, melee, reserved]
        var loadout = EquipmentLoadout(itemIDsBySlot: [.weapon: bow.id, .secondaryWeapon: quiver.id])
        #expect(!loadout.canEquip(melee, in: .weapon, inventory: inventory))
        let upgrade = try #require(SimulationEquipmentPolicy.nextUpgrade(
            for: owner, inventory: inventory, loadout: loadout, reservedItemIDs: [reserved.id],
        ))
        #expect(upgrade.itemID == melee.id)
        #expect(upgrade.unequipFirst == .secondaryWeapon)
        if let slot = upgrade.unequipFirst {
            loadout.unequip(slot)
        }
        loadout.equip(melee, in: upgrade.slot, inventory: inventory)
        #expect(loadout.itemID(for: .weapon) == melee.id)
        #expect(loadout.itemID(for: .secondaryWeapon) == nil)
        #expect(loadout.sanitized(for: owner, inventory: inventory) == loadout)
        #expect(inventory.contains { $0.id == quiver.id })
    }

    @Test func `quiver removal never hides a downgrade in the complete weapon pair`() throws {
        let owner = try holyKnight()
        let bow = try basedItem("bow", baseID: "shortbow", count: 2)
        let quiver = try basedItem("quiver", baseID: "quiver", count: 4)
        let melee = try basedItem("melee", baseID: "maul", count: 3)
        #expect(SimulationEquipmentPolicy.nextUpgrade(
            for: owner, inventory: [bow, quiver, melee],
            loadout: EquipmentLoadout(itemIDsBySlot: [.weapon: bow.id, .secondaryWeapon: quiver.id]),
        ) == nil)
    }

    private func basedItem(_ id: String, baseID: String, count: Int) throws -> InventoryItem {
        let base = try #require(GameContent.itemBaseType(matching: baseID))
        return InventoryItem(
            id: id,
            baseType: base,
            rarity: .basic,
            displayName: id,
            affixes: (0 ..< count).map { ItemAffix(id: "generic-\($0)", title: "Generic", description: "", keywords: []) },
        )
    }

    private func holyKnight() throws -> Combatant {
        let knight = try #require(GameContent.hero(matching: "knight"))
        return knight.withAbilityLoadout(AbilityLoadout(
            basic: AbilityCatalog.block,
            skill: AbilityCatalog.smite,
            ultimate: AbilityCatalog.earthquake,
        ))
    }

    private func rolledItem(_ id: String, affixID: String, high: Bool) throws -> InventoryItem {
        let definition = try #require(GameContent.itemAffixDefinition(matching: affixID))
        let power = definition.power(for: .basic)
        let slot = definition.slot
        return InventoryItem(
            id: id, baseType: ItemBaseType(
                id: id,
                name: id,
                slot: slot,
                weaponKind: slot == .weapon ? .oneHanded : nil,
                keywordAffinities: [],
            ),
            rarity: .basic, displayName: id, affixes: [definition.resolved(for: .basic)],
            affixPowers: [high ? power.rolledMax() : power.rolledMin()],
        )
    }

    private func item(_ id: String, slot: ItemSlot, count: Int, kind: ItemBaseType.WeaponKind? = nil) -> InventoryItem {
        InventoryItem(
            id: id, baseType: ItemBaseType(id: id, name: id, slot: slot, weaponKind: kind, keywordAffinities: []),
            rarity: .basic, displayName: id,
            affixes: (0 ..< count).map { ItemAffix(id: "generic-\($0)", title: "Generic", description: "", keywords: []) },
        )
    }
}
