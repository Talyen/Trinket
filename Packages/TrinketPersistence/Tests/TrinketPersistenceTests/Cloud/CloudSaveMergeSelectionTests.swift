import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct CloudSaveMergeSelectionTests {
    @Test @MainActor func `independent ability tier edits survive cloud merge and reload`() throws {
        var base = PlayerSave.testSeed
        base.modifiedAt = Date(timeIntervalSince1970: 1)
        let hero = try #require(GameContent.hero(matching: "knight"))
        let basic = try #require(hero.abilityChoices.basics.dropFirst().first)
        let skill = try #require(hero.abilityChoices.skills.dropFirst().first)
        var earlier = base
        earlier.roster.setLoadout(earlier.roster.loadout(for: hero).selecting(basic), for: hero)
        earlier.modifiedAt = Date(timeIntervalSince1970: 100)
        var later = base
        later.roster.setLoadout(later.roster.loadout(for: hero).selecting(skill), for: hero)
        later.modifiedAt = Date(timeIntervalSince1970: 200)

        let merged = CloudSaveMerge.merge(incoming: earlier, existing: later, base: base, preferIncoming: false)
        let context = try PersistenceTestContext()
        let restored = try context.seedAndReload(merged)
        #expect(restored.roster.loadout(for: hero).basic?.id == basic.id)
        #expect(restored.roster.loadout(for: hero).skill?.id == skill.id)
        #expect(restored.roster.loadout(for: hero).ultimate?.id == hero.abilityLoadout.ultimate?.id)
    }

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

    @Test @MainActor func `the latest valid weapon pair survives an offline item move and reload`() throws {
        var base = PlayerSave.testSeed
        base.modifiedAt = Date(timeIntervalSince1970: 1)
        let knight = try #require(GameContent.hero(matching: "knight"))
        let alchemist = try #require(GameContent.hero(matching: "alchemist"))
        let longsword = try #require(base.inventory.item(matching: "longsword-basic"))
        let longbow = try #require(base.inventory.item(matching: "longbow-basic"))
        let shield = try #require(base.inventory.item(matching: "kite_shield-basic"))
        var older = base
        var alchemistLoadout = older.roster.equipmentLoadout(for: alchemist)
        alchemistLoadout.equip(longsword, in: .weapon, inventory: older.inventory.items)
        older.roster.setEquipmentLoadout(alchemistLoadout, for: alchemist)
        var bowLoadout = older.roster.equipmentLoadout(for: knight)
        bowLoadout.equip(longbow, in: .weapon, inventory: older.inventory.items)
        older.roster.setEquipmentLoadout(bowLoadout, for: knight)
        older.modifiedAt = Date(timeIntervalSince1970: 100)
        var recent = base
        var shieldLoadout = recent.roster.equipmentLoadout(for: knight)
        shieldLoadout.equip(shield, in: .secondaryWeapon, inventory: recent.inventory.items)
        recent.roster.setEquipmentLoadout(shieldLoadout, for: knight)
        recent.modifiedAt = Date(timeIntervalSince1970: 200)

        #expect(older.roster.equipmentLoadout(for: alchemist).itemID(for: .weapon) == longsword.id)
        #expect(older.roster.equipmentLoadout(for: knight).itemID(for: .weapon) == longbow.id)
        #expect(shieldLoadout.sanitized(for: knight, inventory: recent.inventory.items) == shieldLoadout)
        let merged = CloudSaveMerge.merge(incoming: older, existing: recent, base: base, preferIncoming: false)
        let context = try PersistenceTestContext()
        let restored = try context.seedAndReload(merged)

        #expect(restored.roster.equipmentLoadout(for: knight).itemID(for: .weapon) == longsword.id)
        #expect(restored.roster.equipmentLoadout(for: knight).itemID(for: .secondaryWeapon) == shield.id)
        #expect(restored.roster.equipmentLoadout(for: alchemist).itemID(for: .weapon) == nil)
        #expect(restored.roster.equippedCombatantID(for: longbow.id) == nil)
        #expect(restored.inventory.item(matching: longbow.id) != nil)
        let equippedIDs = restored.roster.equipmentLoadouts.values.flatMap(\.itemIDsBySlot.values)
        #expect(equippedIDs.count == Set(equippedIDs).count)
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
