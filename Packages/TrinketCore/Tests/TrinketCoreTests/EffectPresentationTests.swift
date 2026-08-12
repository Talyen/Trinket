import Testing
import TrinketCore

struct EffectPresentationTests {
    @Test(arguments: [
        (
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 3, 10), remainingTurns: 0),
            "Stun Build-up: 3/10" as String?
        ),
        (
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 2),
            "Stunned"
        ),
        (
            ActiveEffect(id: 1, effect: .deathsDoor, remainingTurns: 8),
            "Death's Door"
        ),
        (
            ActiveEffect(id: 1, effect: .avatar(holyDamage: 6, blockPerTurn: 4, turns: 1), remainingTurns: 1),
            "Avatar"
        ),
    ])
    func activePhraseFormatsKnownEffects(active: ActiveEffect, expected: String?) throws {
        try #expect(EffectPresentation.activePhrase(for: active) == expected)
    }

    @Test(arguments: [
        (Effect.shield(.block, 5), "gain 5 Block"),
        (Effect.thorns(1), "gain 1 Thorns"),
        (Effect.bleed(2), "applies Bleeding: 2 damage"),
        (Effect.burn(4), "applies Burning: 4 damage"),
        (Effect.poison(3), "applies Poisoned: 3 damage"),
        (
            .damageKeywordOverride(.holy, 3, 6),
            "your attacks become Holy damage and deal +3 for 6 turns"
        ),
        (.nextStrikeDouble, "your next attack deals double damage"),
        (.evadeNextHit, "dodge the next attack"),
        (
            .avatar(holyDamage: 6, blockPerTurn: 4, turns: 1),
            "deal 6 Holy damage and gain 4 Block each turn for 1 turn"
        ),
    ])
    func applyPhraseFormatsKnownEffects(effect: Effect, expected: String) throws {
        try #expect(EffectPresentation.applyPhrase(for: effect) == expected)
    }
}
