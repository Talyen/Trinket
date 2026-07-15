import Testing
import TrinketCore

struct EffectPresentationTests {
    @Test(arguments: [
        (
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 3, 10), remainingTicks: 0),
            "Stun Build-up: 3/10" as String?
        ),
        (
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 2),
            "Stunned"
        ),
        (
            ActiveEffect(id: 1, effect: .deathsDoor, remainingTicks: 8),
            "Death's Door"
        )
    ])
    func activePhraseFormatsKnownEffects(active: ActiveEffect, expected: String?) throws {
        try #expect(EffectPresentation.activePhrase(for: active) == expected)
    }

    @Test(arguments: [
        (Effect.shield(.block, 5), "gain 5 Block"),
        (
            .damageKeywordOverride(.holy, 3, 6),
            "your attacks become Holy damage and deal +3 for 6 turns"
        )
    ])
    func applyPhraseFormatsKnownEffects(effect: Effect, expected: String) throws {
        try #expect(EffectPresentation.applyPhrase(for: effect) == expected)
    }
}
