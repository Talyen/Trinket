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

    private func item(_ id: String, slot: ItemSlot, count: Int, kind: ItemBaseType.WeaponKind? = nil) -> InventoryItem {
        InventoryItem(
            id: id, baseType: ItemBaseType(id: id, name: id, slot: slot, weaponKind: kind, keywordAffinities: []),
            rarity: .basic, displayName: id,
            affixes: (0 ..< count).map { ItemAffix(id: "generic-\($0)", title: "Generic", description: "", keywords: []) },
        )
    }
}
