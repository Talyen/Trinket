import Foundation
import Testing
import TrinketCore

struct CoreValueTypesTests {
    @Test func `power snapshot compares and hashes by value`() {
        let first = CombatPowerSnapshot(level: 5, maxHealth: 40, rawDamagePercent: 1.2)
        let second = CombatPowerSnapshot(level: 5, maxHealth: 40, rawDamagePercent: 1.2)
        #expect(first == second)
        #expect(Set([first, second]).count == 1)
        #expect(first != CombatPowerSnapshot(level: 6, maxHealth: 40, rawDamagePercent: 1.2))
    }

    @Test func `secondary slots collapse to base display names`() {
        #expect(ItemSlot.secondaryWeapon.baseItemSlot == .weapon)
        #expect(ItemSlot.secondaryAccessory.baseItemSlot == .accessory)
        #expect(ItemSlot.secondaryTrinket.baseItemSlot == .trinket)
        #expect(ItemSlot.weapon.baseItemSlot == .weapon)
        #expect(ItemSlot.secondaryWeapon.displayName == ItemSlot.weapon.rawValue)
        #expect(ItemSlot.secondaryWeapon.accessibilityIdentifier != ItemSlot.weapon.accessibilityIdentifier)
        #expect(ItemSlot.secondaryWeapon.accepts(.weapon))
        #expect(ItemSlot.secondaryWeapon.accepts(.secondaryWeapon))
        #expect(!ItemSlot.secondaryWeapon.accepts(.armor))
        #expect(ItemSlot.weapon.accepts(.weapon))
        #expect(ItemSlot.weapon.accepts(.secondaryWeapon))
    }

    @Test func `collection safe subscript retrieves element or nil out of bounds`() {
        let items = [10, 20, 30]
        #expect(items[safe: 0] == 10)
        #expect(items[safe: 1] == 20)
        #expect(items[safe: 2] == 30)
        #expect(items[safe: -1] == nil)
        #expect(items[safe: 3] == nil)
        #expect(items[safe: 100] == nil)

        let empty: [Int] = []
        #expect(empty[safe: 0] == nil)
        #expect(empty[safe: -1] == nil)

        let slice = items[1 ... 2]
        #expect(slice[safe: 0] == nil)
        #expect(slice[safe: 1] == 20)
        #expect(slice[safe: 2] == 30)
        #expect(slice[safe: 3] == nil)
    }

    @Test func `active effect awaits skip only at zero remaining turns`() {
        let pending = ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0)
        #expect(pending.isAwaitingActionSkip)
        #expect(pending.keyword == .stun)
        #expect(!ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 1).isAwaitingActionSkip)
        #expect(!ActiveEffect(id: 2, effect: .burn(3), remainingTurns: 0).isAwaitingActionSkip)
    }

    @Test func `effect summary identifies by keyword and text`() {
        let summary = EffectSummary(keyword: .burn, text: "Burning: 3 damage")
        #expect(summary.id == "Burn:Burning: 3 damage")
        #expect(summary == EffectSummary(keyword: .burn, text: "Burning: 3 damage"))
    }

    @Test func `homestead node identifiers stay explicit`() {
        #expect(HomesteadNodeID.wheatField.rawValue == "wheatField")
        #expect(HomesteadNodeID.allCases.count == 20)
        #expect(ResourceAmount(.gold, 5).id == .gold)
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

    @Test func `damage conditions have non empty unique sentence fragments`() {
        let conditions = DamageCondition.allCases
        #expect(!conditions.isEmpty)
        #expect(conditions.count == Set(conditions).count)

        for condition in conditions {
            #expect(!condition.sentenceFragment.isEmpty, "\(condition) should have a sentence fragment")
            #expect(!condition.sentenceFragment.hasSuffix("."), "\(condition) fragment should omit trailing period")
        }

        let fragments = conditions.map(\.sentenceFragment)
        #expect(fragments.count == Set(fragments).count)
    }

    @Test func `core domain enums encode and decode correctly`() throws {
        for slot in ItemSlot.allCases {
            let data = try JSONEncoder().encode(slot)
            let decoded = try JSONDecoder().decode(ItemSlot.self, from: data)
            #expect(decoded == slot)
        }

        for faction in EnemyFaction.allCases {
            let data = try JSONEncoder().encode(faction)
            let decoded = try JSONDecoder().decode(EnemyFaction.self, from: data)
            #expect(decoded == faction)
        }

        for category in HomesteadNodeCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(HomesteadNodeCategory.self, from: data)
            #expect(decoded == category)
        }
    }
}
