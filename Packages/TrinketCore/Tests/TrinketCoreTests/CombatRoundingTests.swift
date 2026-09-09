import Testing
import TrinketCore

struct CombatRoundingTests {
    @Test func `scaled percent multiplier uses rounded`() {
        #expect(CombatRounding.scaled(2, multiplier: 0.8) == 2)
        #expect(CombatRounding.scaled(3, multiplier: 0.8) == 2)
        #expect(CombatRounding.scaled(5, multiplier: 0.8) == 4)
        #expect(CombatRounding.scaled(2, multiplier: 1.3) == 3)
    }

    @Test func `scaled returns zero for non positive base`() {
        #expect(CombatRounding.scaled(0, multiplier: 0.8) == 0)
        #expect(CombatRounding.scaled(-2, multiplier: 0.8) == 0)
    }

    @Test func `rounded clamps negative results to zero`() {
        #expect(CombatRounding.rounded(-0.4) == 0)
    }

    @Test func `rounding at integer limit saturates without trapping`() {
        #expect(CombatRounding.rounded(Double(Int.max)) == Int.max)
        #expect(CombatRounding.scaled(Int.max, multiplier: 2) == Int.max)
    }

    @Test func `scaled by percent rounds ties to even`() {
        #expect(CombatRounding.scaled(15, byPercent: 5) == 16)
        #expect(CombatRounding.scaled(10, byPercent: 25) == 13)
        #expect(CombatRounding.scaled(10, byPercent: 50) == 15)
        #expect(CombatRounding.scaled(10, byPercent: -50) == 5)
        #expect(CombatRounding.scaled(0, byPercent: 50) == 0)
        #expect(CombatRounding.scaled(-10, byPercent: 50) == 0)
    }
}
