import TrinketCore
import Testing

@Suite
struct EffectPresentationTests {
    @Test func activePhraseFormatsControlMeterBuildUp() {
        let active = ActiveEffect(
            id: 1,
            effect: .controlMeter(.stun, 3, 10),
            remainingTicks: 0
        )

        #expect(EffectPresentation.activePhrase(for: active) == "Stun Build-up: 3/10")
    }

    @Test func activePhraseFormatsTriggeredControlAsStatusAlias() {
        let active = ActiveEffect(
            id: 1,
            effect: .controlMeter(.stun, 10, 10),
            remainingTicks: 2
        )

        #expect(EffectPresentation.activePhrase(for: active) == "Stunned")
    }

    @Test func activePhraseFormatsDeathsDoor() {
        let active = ActiveEffect(
            id: 1,
            effect: .deathsDoor,
            remainingTicks: 8
        )

        #expect(EffectPresentation.activePhrase(for: active) == "Death's Door")
    }
}
