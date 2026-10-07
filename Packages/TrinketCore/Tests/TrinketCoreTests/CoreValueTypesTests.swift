import Foundation
import Testing
import TrinketCore

struct CoreValueTypesTests {
    @Test func `secondary slots collapse to base display names`() {
        #expect(ItemSlot.secondaryWeapon.baseItemSlot == .weapon)
        #expect(ItemSlot.secondaryAccessory.baseItemSlot == .accessory)
        #expect(ItemSlot.secondaryTrinket.baseItemSlot == .trinket)
        #expect(ItemSlot.weapon.baseItemSlot == .weapon)
        #expect(ItemSlot.secondaryWeapon.isSecondary)
        #expect(ItemSlot.secondaryAccessory.isSecondary)
        #expect(ItemSlot.secondaryTrinket.isSecondary)
        #expect(!ItemSlot.weapon.isSecondary)
        #expect(!ItemSlot.armor.isSecondary)
        #expect(ItemSlot.secondaryWeapon.displayName == ItemSlot.weapon.rawValue)
        #expect(ItemSlot.secondaryWeapon.accessibilityIdentifier != ItemSlot.weapon.accessibilityIdentifier)
        #expect(ItemSlot.secondaryWeapon.accepts(.weapon))
        #expect(ItemSlot.secondaryWeapon.accepts(.secondaryWeapon))
        #expect(!ItemSlot.secondaryWeapon.accepts(.armor))
        #expect(ItemSlot.weapon.accepts(.weapon))
        #expect(ItemSlot.weapon.accepts(.secondaryWeapon))
    }

    @Test func `active effect awaits skip only at zero remaining turns`() {
        let pending = ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0)
        #expect(pending.isAwaitingActionSkip)
        #expect(pending.keyword == .stun)
        #expect(!ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 1).isAwaitingActionSkip)
        #expect(!ActiveEffect(id: 2, effect: .burn(3), remainingTurns: 0).isAwaitingActionSkip)
    }

    @Test func `homestead resource resolves retired crystal alias as gems`() throws {
        #expect(HomesteadResource.resolving(resourceID: "crystal") == .gems)
        #expect(HomesteadResource.resolving(resourceID: "gems") == .gems)
        #expect(HomesteadResource.resolving(resourceID: "gold") == .gold)
        #expect(HomesteadResource.resolving(resourceID: "mana") == nil)

        let legacy = try JSONDecoder().decode(HomesteadResource.self, from: Data("\"crystal\"".utf8))
        #expect(legacy == .gems)
        let encoded = try JSONEncoder().encode(HomesteadResource.gems)
        #expect(try #require(String(bytes: encoded, encoding: .utf8)) == "\"gems\"")

        let balances = try JSONEncoder().encode([HomesteadResource.gems: 4])
        let roundTripped = try JSONDecoder().decode([HomesteadResource: Int].self, from: balances)
        #expect(roundTripped == [.gems: 4])

        // Saves written before the rename persist this balance under "crystal".
        let legacyJSON = try #require(String(bytes: balances, encoding: .utf8))
            .replacingOccurrences(of: "gems", with: "crystal")
        let migrated = try JSONDecoder().decode([HomesteadResource: Int].self, from: Data(legacyJSON.utf8))
        #expect(migrated == [.gems: 4])
    }

    @Test func `homestead node resolves retired scriptorium alias as library`() throws {
        #expect(HomesteadNodeID.resolving(nodeID: "scriptorium") == .library)
        #expect(HomesteadNodeID.resolving(nodeID: "library") == .library)
        #expect(HomesteadNodeID.resolving(nodeID: "wheatField") == .wheatField)
        #expect(HomesteadNodeID.resolving(nodeID: "mana") == nil)

        let legacy = try JSONDecoder().decode(HomesteadNodeID.self, from: Data("\"scriptorium\"".utf8))
        #expect(legacy == .library)
        let encoded = try JSONEncoder().encode(HomesteadNodeID.library)
        #expect(try #require(String(bytes: encoded, encoding: .utf8)) == "\"library\"")

        let tiers = try JSONEncoder().encode([HomesteadNodeID.library: 2])
        let roundTripped = try JSONDecoder().decode([HomesteadNodeID: Int].self, from: tiers)
        #expect(roundTripped == [.library: 2])

        // Saves written before the rename persist this tier under "scriptorium".
        let legacyJSON = try #require(String(bytes: tiers, encoding: .utf8))
            .replacingOccurrences(of: "library", with: "scriptorium")
        let migrated = try JSONDecoder().decode([HomesteadNodeID: Int].self, from: Data(legacyJSON.utf8))
        #expect(migrated == [.library: 2])
    }
}
