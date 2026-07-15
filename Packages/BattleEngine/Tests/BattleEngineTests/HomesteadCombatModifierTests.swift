import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct HomesteadCombatModifierTests {
    @Test func manaCostReductionRoundsDownAndAllowsZero() throws {
        var profile = CombatModifierProfile.zero
        profile.merge(.manaCostReductionPercent(0.15))

        let ability = Ability(
            id: "test-ability",
            name: "Test",
            tier: .skill,
            manaCost: 4
        )
        try #expect(profile.effectiveManaCost(for: ability) == 3)

        profile.merge(.manaCostReductionPercent(0.85))
        try #expect(profile.effectiveManaCost(for: ability) == 0)
    }
}
