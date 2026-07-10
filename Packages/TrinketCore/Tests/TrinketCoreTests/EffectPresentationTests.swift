import TrinketCore
import Testing

@Suite
struct EffectPresentationTests {
    @Test func activePhraseFormatsControlMeterBuildUp() throws {
        let active = ActiveEffect(
            id: 1,
            effect: .controlMeter(.stun, 3, 10),
            remainingTicks: 0
        )

        try #expect(EffectPresentation.activePhrase(for: active) == "Stun Build-up: 3/10")
    }

    @Test func activePhraseFormatsTriggeredControlAsStatusAlias() throws {
        let active = ActiveEffect(
            id: 1,
            effect: .controlMeter(.stun, 10, 10),
            remainingTicks: 2
        )

        try #expect(EffectPresentation.activePhrase(for: active) == "Stunned")
    }

    @Test func activePhraseFormatsDeathsDoor() throws {
        let active = ActiveEffect(
            id: 1,
            effect: .deathsDoor,
            remainingTicks: 8
        )

        try #expect(EffectPresentation.activePhrase(for: active) == "Death's Door")
    }

    @Test func applyPhraseFormatsBlockWithAmount() throws {
        try #expect(
            EffectPresentation.applyPhrase(for: .shield(.block, 5))
                == "gain 5 Block"
        )
    }

    @Test func applyPhraseFormatsArmorWithAmount() throws {
        try #expect(
            EffectPresentation.applyPhrase(for: .mitigation(.armor, 2))
                == "gain 2 Armor"
        )
    }

    @Test func applyPhraseFormatsDamageKeywordOverride() throws {
        try #expect(
            EffectPresentation.applyPhrase(for: .damageKeywordOverride(.holy, 3, 6))
                == "your attacks become Holy damage and deal +3 for 6 turns"
        )
    }

    @Test func activePhraseFormatsDamageKeywordOverride() throws {
        let active = ActiveEffect(
            id: 1,
            effect: .damageKeywordOverride(.holy, 3, 6),
            remainingTicks: 6
        )
        try #expect(EffectPresentation.activePhrase(for: active) == "Consecrated")
    }
}
