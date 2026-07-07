import Testing
import BattleEngine
import TrinketCore
import TrinketContent

/// Representative formatter coverage. Battle tests assert event semantics; this file
/// only locks a few display categories so emphasis mapping does not regress silently.
@Suite
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

    @Test func abilityDamageFormatsAsNegativeAmount() {
        let display = ActionEventFormatter.display(
            for: event(kind: .ability, amount: 3, keyword: .physical)
        )
        #expect(display.text == "-3")
        #expect(display.emphasis == .damage)
        #expect(display.keyword == .physical)
    }

    @Test func instantHealFormatsAsPositiveWithKeyword() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .instantHeal, amount: 3, keyword: .health)
        )
        #expect(display.text == "+3 Health")
        #expect(display.emphasis == .heal)
    }

    @Test func controlTriggeredUsesStatusAlias() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .controlTriggered, keyword: .stun)
        )
        #expect(display.text == "Stunned!")
        #expect(display.emphasis == .control)
    }

    @Test func secondaryTextIsAlwaysNil() {
        let cases: [ActionEvent] = [
            event(kind: .ability, amount: 3, keyword: .physical),
            event(kind: .status, amount: 1, keyword: .burn),
            event(kind: .effect, effectKind: .instantHeal, amount: 1, keyword: .health),
            event(kind: .effect, effectKind: .dodgeApplied, keyword: .dodge)
        ]
        for event in cases {
            #expect(
                ActionEventFormatter.display(for: event == nil).secondaryText,
                "secondaryText should be nil for \(event)"
            )
        }
    }
}
