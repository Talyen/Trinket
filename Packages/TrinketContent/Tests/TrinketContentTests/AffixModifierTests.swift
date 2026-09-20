import Foundation
import Testing
import TrinketCore
@testable import TrinketContent

struct AffixModifierTests {
    @Test(arguments: [
        (AffixModifier.maximumHealth(4), #"{"maximumHealth":{"_0":4}}"#),
        (AffixModifier.maximumMana(4), #"{"maximumMana":{"_0":4}}"#),
        (AffixModifier.criticalDamage(4), #"{"criticalDamage":{"_0":4}}"#),
        (AffixModifier.manaRestored(4), #"{"manaRestored":{"_0":4}}"#),
        (AffixModifier.damageDealt(.burn, 4), #"{"damageDealt":{"_0":"Burn","_1":4}}"#),
        (AffixModifier.poisonDamageDealtPercent(0.25), #"{"poisonDamageDealtPercent":{"_0":0.25}}"#),
        (AffixModifier.healthRestored(4), #"{"healthRestored":{"_0":4}}"#),
        (AffixModifier.leechGainedPercent(0.25), #"{"leechGainedPercent":{"_0":0.25}}"#),
        (AffixModifier.leechHealing(4), #"{"leechHealing":{"_0":4}}"#),
        (AffixModifier.goldGained(4), #"{"goldGained":{"_0":4}}"#),
        (AffixModifier.goldGainedPercent(0.25), #"{"goldGainedPercent":{"_0":0.25}}"#),
        (AffixModifier.blockGained(4), #"{"blockGained":{"_0":4}}"#),
        (AffixModifier.bleedDuration(4), #"{"bleedDuration":{"_0":4}}"#),
        (AffixModifier.damageTakenPercent(.burn, 0.25), #"{"damageTakenPercent":{"_0":"Burn","_1":0.25}}"#),
        (AffixModifier.damageTakenFlat(.burn, 4), #"{"damageTakenFlat":{"_0":"Burn","_1":4}}"#),
        (AffixModifier.damageTakenVulnerability(.burn, 0.25), #"{"damageTakenVulnerability":{"_0":"Burn","_1":0.25}}"#),
        (AffixModifier.companionDamageDealt(4), #"{"companionDamageDealt":{"_0":4}}"#),
        (AffixModifier.companionPhysicalDamageDealt(4), #"{"companionPhysicalDamageDealt":{"_0":4}}"#),
        (AffixModifier.companionBleedDamageDealt(4), #"{"companionBleedDamageDealt":{"_0":4}}"#),
        (AffixModifier.outgoingDamagePercent(0.25), #"{"outgoingDamagePercent":{"_0":0.25}}"#),
        (AffixModifier.incomingDamageReductionPercent(0.25), #"{"incomingDamageReductionPercent":{"_0":0.25}}"#),
        (AffixModifier.dodgeChanceBonus(0.25), #"{"dodgeChanceBonus":{"_0":0.25}}"#),
        (AffixModifier.rangedDamageDealt(4), #"{"rangedDamageDealt":{"_0":4}}"#),
        (AffixModifier.maximumManaPercent(0.25), #"{"maximumManaPercent":{"_0":0.25}}"#),
    ])
    func `generated modifiers preserve saved representations`(modifier: AffixModifier, saved: String) throws {
        let data = Data(saved.utf8)
        #expect(try JSONDecoder().decode(AffixModifier.self, from: data) == modifier)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(try encoder.encode(modifier) == data)
    }

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
