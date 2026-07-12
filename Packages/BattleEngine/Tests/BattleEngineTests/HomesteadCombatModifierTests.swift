import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct HomesteadCombatModifierTests {
    @Test func flatFreezeReductionLowersIncomingFreezeDamage() throws {
        var profile = CombatModifierProfile.zero
        profile.merge(.damageTakenFlat(.freeze, 2))

        var remaining = 5
        let flatReduction = profile.damageTakenFlat(for: .freeze)
        remaining = max(0, remaining - flatReduction)
        try #expect(remaining == 3)
    }

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
