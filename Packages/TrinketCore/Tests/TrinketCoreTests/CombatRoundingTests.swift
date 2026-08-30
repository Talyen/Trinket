import Testing
import TrinketCore

struct CombatRoundingTests {
    @Test func `scaled percent multiplier uses rounded`() throws {
        try #expect(CombatRounding.scaled(2, multiplier: 0.8) == 2)
        try #expect(CombatRounding.scaled(3, multiplier: 0.8) == 2)
        try #expect(CombatRounding.scaled(5, multiplier: 0.8) == 4)
        try #expect(CombatRounding.scaled(2, multiplier: 1.3) == 3)
    }

    @Test func `scaled returns zero for non positive base`() throws {
        try #expect(CombatRounding.scaled(0, multiplier: 0.8) == 0)
        try #expect(CombatRounding.scaled(-2, multiplier: 0.8) == 0)
    }

    @Test func `rounded clamps negative results to zero`() throws {
        try #expect(CombatRounding.rounded(-0.4) == 0)
    }

    @Test func `scaled by percent rounds ties to even`() throws {
        try #expect(CombatRounding.scaled(15, byPercent: 5) == 16)
        try #expect(CombatRounding.scaled(10, byPercent: 25) == 13)
        try #expect(CombatRounding.scaled(10, byPercent: 50) == 15)
        try #expect(CombatRounding.scaled(10, byPercent: -50) == 5)
        try #expect(CombatRounding.scaled(0, byPercent: 50) == 0)
        try #expect(CombatRounding.scaled(-10, byPercent: 50) == 0)
    }
}
