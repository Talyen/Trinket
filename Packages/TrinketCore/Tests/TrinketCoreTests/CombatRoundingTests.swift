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
}
