import BattleEngine
import Testing
import TrinketContent
import TrinketCore

/// Representative formatter coverage. Battle tests assert event semantics; this file
/// only locks a few display categories so emphasis mapping does not regress silently.
struct ActionEventFormatterTests {
    private func event(
        id: Int = 1,
        kind: ActionEvent.Kind,
        effectKind: ActionEvent.EffectKind? = nil,
        amount: Int = 0,
        keyword: Keyword = .physical,
        targetID: String = "target",
        targetName: String = "Target"
    ) -> ActionEvent {
        ActionEvent(
            id: id,
            kind: kind,
            effectKind: effectKind,
            actorName: "Actor",
            abilityName: "Ability",
            targetID: targetID,
            targetName: targetName,
            amount: amount,
            keyword: keyword
        )
    }

    @Test func abilityDamageFormatsAsNegativeAmount() throws {
        let display = ActionEventFormatter.display(
            for: event(kind: .ability, amount: 3, keyword: .physical)
        )
        try #expect(display.text == "-3")
        try #expect(display.emphasis == .damage)
        try #expect(display.keyword == .physical)
        try #expect(display.secondaryText == nil)
    }

    @Test func instantHealFormatsAsPositiveWithKeyword() throws {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .instantHeal, amount: 3, keyword: .health)
        )
        try #expect(display.text == "+3 Health")
        try #expect(display.emphasis == .heal)
        try #expect(display.secondaryText == nil)
    }

    @Test func negativeResourceGainFormatsWithMinusPrefix() throws {
        let display = ActionEventFormatter.display(
            for: event(
                kind: .effect,
                effectKind: .resourceGain,
                amount: -3,
                keyword: .gold
            )
        )
        try #expect(display.text == "-3 Gold")
        try #expect(display.emphasis == .resourceGain)
        try #expect(display.keyword == .gold)
    }

    @Test func controlTriggeredUsesStatusAlias() throws {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .controlTriggered, keyword: .stun)
        )
        try #expect(display.text == "Stunned!")
        try #expect(display.emphasis == .control)
        try #expect(display.secondaryText == nil)
    }
}
