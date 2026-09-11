import Testing
import TrinketCore
@testable import TrinketContent

struct AffixModifierTests {
    @Test func `percent classification matches numeric kind`() {
        #expect(!AffixModifier.maximumHealth(4).isPercent)
        #expect(!AffixModifier.damageDealt(.burn, 2).isPercent)
        #expect(!AffixModifier.companionDamageDealt(1).isPercent)
        #expect(AffixModifier.outgoingDamagePercent(0.02).isPercent)
        #expect(AffixModifier.dodgeChanceBonus(0.02).isPercent)
        #expect(AffixModifier.damageTakenPercent(.burn, 0.1).isPercent)
    }

    @Test func `numeric value round-trips both kinds`() {
        #expect(AffixModifier.maximumHealth(4).numericValue == 4)
        #expect(AffixModifier.damageDealt(.burn, 2).numericValue == 2)
        #expect(AffixModifier.outgoingDamagePercent(0.02).numericValue == 0.02)
    }

    @Test func `maps transform their own kind and leave the other`() {
        #expect(AffixModifier.maximumHealth(4).mapInt { $0 * 2 } == .maximumHealth(8))
        #expect(AffixModifier.maximumHealth(4).mapPercent { $0 * 2 } == .maximumHealth(4))
        #expect(
            AffixModifier.outgoingDamagePercent(0.02).mapPercent { $0 * 2 }
                == .outgoingDamagePercent(0.04),
        )
        #expect(
            AffixModifier.outgoingDamagePercent(0.02).mapInt { $0 * 2 }
                == .outgoingDamagePercent(0.02),
        )
    }

    @Test func `bumps stop at the smallest unit`() {
        #expect(AffixModifier.maximumHealth(2).bumped(intDelta: 1, percentDelta: 0.01) == .maximumHealth(3))
        #expect(AffixModifier.maximumHealth(1).bumped(intDelta: -1, percentDelta: -0.01) == nil)
        #expect(
            AffixModifier.dodgeChanceBonus(0.02).bumped(intDelta: -1, percentDelta: -0.01)
                == .dodgeChanceBonus(0.01),
        )
        #expect(
            AffixModifier.dodgeChanceBonus(0.01).bumped(intDelta: -1, percentDelta: -0.01) == nil,
        )
    }
}
