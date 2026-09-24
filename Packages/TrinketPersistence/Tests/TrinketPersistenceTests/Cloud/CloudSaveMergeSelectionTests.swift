import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct CloudSaveMergeSelectionTests {
    @Test func `newly equipped gear survives a later unrelated device action`() {
        var base = PlayerSave.testSeed
        base.modifiedAt = Date(timeIntervalSince1970: 1)
        var equipped = base
        equipped.roster.equipmentLoadouts["knight"] = EquipmentLoadout(itemIDsBySlot: [
            .weapon: "longsword-basic",
            .armor: "plate_armor-basic",
            .accessory: "ruby_ring-astral",
        ])
        equipped.modifiedAt = Date(timeIntervalSince1970: 100)
        var later = base
        later.roster.gold += 5
        later.modifiedAt = Date(timeIntervalSince1970: 200)

        let merged = CloudSaveMerge.merge(incoming: equipped, existing: later, base: base, preferIncoming: false)

        #expect(merged.roster.equipmentLoadouts["knight"]?.itemID(for: .accessory) == "ruby_ring-astral")
        #expect(merged.roster.gold == base.roster.gold + 5)
    }

    @Test func `the latest equipment choice wins when devices move the same item`() {
        var base = PlayerSave.testSeed
        base.modifiedAt = Date(timeIntervalSince1970: 1)
        var earlier = base
        var knight = earlier.roster.equipmentLoadouts["knight"] ?? EquipmentLoadout()
        knight.itemIDsBySlot[.accessory] = "ruby_ring-astral"
        earlier.roster.equipmentLoadouts["knight"] = knight
        earlier.modifiedAt = Date(timeIntervalSince1970: 100)
        var later = base
        var wizard = later.roster.equipmentLoadouts["wizard"] ?? EquipmentLoadout()
        wizard.itemIDsBySlot[.accessory] = "ruby_ring-astral"
        later.roster.equipmentLoadouts["wizard"] = wizard
        later.modifiedAt = Date(timeIntervalSince1970: 200)

        let merged = CloudSaveMerge.merge(incoming: earlier, existing: later, base: base, preferIncoming: false)
        let playable = PlayerSaveSanitizer.sanitize(merged)

        #expect(playable.roster.equipmentLoadouts["wizard"]?.itemID(for: .accessory) == "ruby_ring-astral")
        #expect(playable.roster.equipmentLoadouts["knight"]?.itemID(for: .accessory) == nil)
        #expect(playable.inventory.item(matching: "ruby_ring-astral") != nil)
    }

    @Test func `the latest slot wins when devices equip the same ring differently`() {
        var base = PlayerSave.testSeed
        base.modifiedAt = Date(timeIntervalSince1970: 1)
        var earlier = base
        var firstSlot = earlier.roster.equipmentLoadouts["knight"] ?? EquipmentLoadout()
        firstSlot.itemIDsBySlot[.accessory] = "ruby_ring-astral"
        earlier.roster.equipmentLoadouts["knight"] = firstSlot
        earlier.modifiedAt = Date(timeIntervalSince1970: 100)
        var later = base
        var secondSlot = later.roster.equipmentLoadouts["knight"] ?? EquipmentLoadout()
        secondSlot.itemIDsBySlot[.secondaryAccessory] = "ruby_ring-astral"
        later.roster.equipmentLoadouts["knight"] = secondSlot
        later.modifiedAt = Date(timeIntervalSince1970: 200)

        let merged = CloudSaveMerge.merge(incoming: earlier, existing: later, base: base, preferIncoming: false)
        let playable = PlayerSaveSanitizer.sanitize(merged)

        #expect(playable.roster.equipmentLoadouts["knight"]?.itemID(for: .secondaryAccessory) == "ruby_ring-astral")
        #expect(playable.roster.equipmentLoadouts["knight"]?.itemID(for: .accessory) == nil)
    }

    @Test func `the latest valid weapon pair survives conflicting offline equipment edits`() {
        var base = PlayerSave.testSeed
        base.modifiedAt = Date(timeIntervalSince1970: 1)
        var older = base
        var bowLoadout = older.roster.equipmentLoadouts["knight"] ?? EquipmentLoadout()
        bowLoadout.itemIDsBySlot[.weapon] = "longbow-basic"
        older.roster.equipmentLoadouts["knight"] = bowLoadout
        older.modifiedAt = Date(timeIntervalSince1970: 100)
        var recent = base
        var shieldLoadout = recent.roster.equipmentLoadouts["knight"] ?? EquipmentLoadout()
        shieldLoadout.itemIDsBySlot[.secondaryWeapon] = "kite_shield-basic"
        recent.roster.equipmentLoadouts["knight"] = shieldLoadout
        recent.modifiedAt = Date(timeIntervalSince1970: 200)

        let merged = CloudSaveMerge.merge(incoming: older, existing: recent, base: base, preferIncoming: false)
        let playable = PlayerSaveSanitizer.sanitize(merged)

        #expect(playable.roster.equipmentLoadouts["knight"]?.itemID(for: .weapon) == "longsword-basic")
        #expect(playable.roster.equipmentLoadouts["knight"]?.itemID(for: .secondaryWeapon) == "kite_shield-basic")
        #expect(playable.inventory.item(matching: "longbow-basic") != nil)
    }

    @Test func `an older weapon edit survives a later unrelated action with an unchanged offhand`() {
        var base = PlayerSave.testSeed
        base.modifiedAt = Date(timeIntervalSince1970: 1)
        base.roster.equipmentLoadouts["knight"]?.itemIDsBySlot[.secondaryWeapon] = "kite_shield-basic"
        var changedWeapon = base
        changedWeapon.roster.equipmentLoadouts["knight"]?.itemIDsBySlot[.weapon] = "longbow-basic"
        changedWeapon.modifiedAt = Date(timeIntervalSince1970: 100)
        var later = base
        later.roster.gold += 5
        later.modifiedAt = Date(timeIntervalSince1970: 200)

        let merged = CloudSaveMerge.merge(incoming: changedWeapon, existing: later, base: base, preferIncoming: false)
        let playable = PlayerSaveSanitizer.sanitize(merged)

        #expect(playable.roster.equipmentLoadouts["knight"]?.itemID(for: .weapon) == "longbow-basic")
        #expect(playable.roster.equipmentLoadouts["knight"]?.itemID(for: .secondaryWeapon) == nil)
        #expect(playable.inventory.item(matching: "kite_shield-basic") != nil)
        #expect(playable.roster.gold == base.roster.gold + 5)
    }
}
