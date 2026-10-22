import Testing
import TrinketCore
@testable import TrinketContent

struct AuthoredAffixRangeTests {
    @Test func `authored ranges survive loot rolling saves scaling and perfect roll checks`() throws {
        let cases: [(String, KeyPath<CombatTraitTriggers, Int>, ClosedRange<Int>, ClosedRange<Int>)] = [
            ("bastioned", \.startBattleBlock, 3 ... 5, 6 ... 8),
            ("cinderbound", \.burnDamageVsBleedingFlat, 1 ... 1, 1 ... 2),
            ("steadfast", \.stunBlockIfNone, 2 ... 3, 4 ... 5),
            ("arcane", \.stunManaIfNone, 1 ... 1, 1 ... 2),
            ("shattering", \.freezeDealPhysicalFlat, 2 ... 3, 4 ... 5),
            ("resolute", \.blockBrokenHealFlat, 1 ... 1, 1 ... 2),
            ("reactive", \.blockBrokenStunFlat, 1 ... 1, 1 ... 2),
        ]
        for (id, keyPath, basic, astral) in cases {
            let definition = try #require(GameContent.itemAffixDefinition(matching: id))
            for (power, range) in [(definition.basic, basic), (definition.astral, astral)] {
                #expect(power.rolledMin().triggers[keyPath: keyPath] == range.lowerBound)
                #expect(power.rolledMax().triggers[keyPath: keyPath] == range.upperBound)
                var rng = SeededRandomNumberGenerator(seed: 4)
                for _ in 0 ..< 64 {
                    let rolled = power.rolled(using: &rng)
                    #expect(range.contains(rolled.triggers[keyPath: keyPath]))
                }
                let restored = try #require(ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([power])).first)
                #expect(restored == power)
                #expect(restored.scaled(by: 2).rolledMax().triggers[keyPath: keyPath] == range.upperBound * 2)
                #expect(power.rolledMax().isAtOrAboveRollMax(of: power))
                if range.lowerBound < range.upperBound {
                    #expect(!power.rolledMin().isAtOrAboveRollMax(of: power))
                }
            }
        }
    }

    @Test func `percentage ranges preserve fixed damage and use every authored percentage point`() throws {
        let cases: [(String, KeyPath<CombatTraitTriggers, Double>, ClosedRange<Int>, ClosedRange<Int>)] = [
            ("bloodletting", \.physicalAttackBleedChancePercent, 10 ... 15, 20 ... 30),
            ("kinbound", \.allyAttackHealBelowHalfPercent, 8 ... 12, 15 ... 20),
        ]
        for (id, keyPath, basic, astral) in cases {
            let definition = try #require(GameContent.itemAffixDefinition(matching: id))
            for (power, range) in [(definition.basic, basic), (definition.astral, astral)] {
                #expect(CombatRounding.wholePercent(power.rolledMin().triggers[keyPath: keyPath]) == range.lowerBound)
                #expect(CombatRounding.wholePercent(power.rolledMax().triggers[keyPath: keyPath]) == range.upperBound)
                var rng = SeededRandomNumberGenerator(seed: 4)
                var seen: Set<Int> = []
                for _ in 0 ..< 256 {
                    let rolled = power.rolled(using: &rng)
                    let points = CombatRounding.wholePercent(rolled.triggers[keyPath: keyPath])
                    #expect(range.contains(points))
                    seen.insert(points)
                    if id == "bloodletting" {
                        #expect(rolled.description.contains("1 Bleed damage"))
                    }
                }
                #expect(seen == Set(range))
            }
        }
    }
}
