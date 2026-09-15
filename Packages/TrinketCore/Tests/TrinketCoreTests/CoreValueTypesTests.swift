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
        #expect(!ItemSlot.secondaryWeapon.accepts(.armor))
        #expect(ItemSlot.weapon.accepts(.weapon))
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
        #expect(HomesteadNodeID.allCases.count == 14)
        #expect(ResourceAmount(.gold, 5).id == .gold)
    }
}
