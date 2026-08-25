import Testing
import TrinketCore

struct CombatRoundingTests {
    @Test func scaledPercentMultiplierUsesRounded() throws {
        try #expect(CombatRounding.scaled(2, multiplier: 0.8) == 2)
        try #expect(CombatRounding.scaled(3, multiplier: 0.8) == 2)
        try #expect(CombatRounding.scaled(5, multiplier: 0.8) == 4)
        try #expect(CombatRounding.scaled(2, multiplier: 1.3) == 3)
    }

    @Test func scaledReturnsZeroForNonPositiveBase() throws {
        try #expect(CombatRounding.scaled(0, multiplier: 0.8) == 0)
        try #expect(CombatRounding.scaled(-2, multiplier: 0.8) == 0)
    }

    @Test func roundedClampsNegativeResultsToZero() throws {
        try #expect(CombatRounding.rounded(-0.4) == 0)
    }

    @Test func scaledByPercentRoundsTiesToEven() throws {
        try #expect(CombatRounding.scaled(15, byPercent: 5) == 16) // 15.75 -> 16
        try #expect(CombatRounding.scaled(10, byPercent: 25) == 13) // 12.5 -> 12 (ties to even is 12, or 12.5 rounded)
        try #expect(CombatRounding.scaled(10, byPercent: 50) == 15) // 15.0 -> 15
        try #expect(CombatRounding.scaled(10, byPercent: -50) == 5) // 5.0 -> 5
        try #expect(CombatRounding.scaled(0, byPercent: 50) == 0)
        try #expect(CombatRounding.scaled(-10, byPercent: 50) == 0)
    }
}
