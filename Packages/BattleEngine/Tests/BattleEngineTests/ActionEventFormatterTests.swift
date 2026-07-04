import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

/// Representative formatter coverage. Battle tests assert event semantics; this file
/// only locks a few display categories so emphasis mapping does not regress silently.
final class ActionEventFormatterTests: XCTestCase {
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

    func testAbilityDamageFormatsAsNegativeAmount() {
        let display = ActionEventFormatter.display(
            for: event(kind: .ability, amount: 3, keyword: .physical)
        )
        XCTAssertEqual(display.text, "-3")
        XCTAssertEqual(display.emphasis, .damage)
        XCTAssertEqual(display.keyword, .physical)
    }

    func testInstantHealFormatsAsPositiveWithKeyword() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .instantHeal, amount: 3, keyword: .health)
        )
        XCTAssertEqual(display.text, "+3 Health")
        XCTAssertEqual(display.emphasis, .heal)
    }

    func testControlTriggeredUsesStatusAlias() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .controlTriggered, keyword: .stun)
        )
        XCTAssertEqual(display.text, "Stunned!")
        XCTAssertEqual(display.emphasis, .control)
    }

    func testSecondaryTextIsAlwaysNil() {
        let cases: [ActionEvent] = [
            event(kind: .ability, amount: 3, keyword: .physical),
            event(kind: .status, amount: 1, keyword: .burn),
            event(kind: .effect, effectKind: .instantHeal, amount: 1, keyword: .health),
            event(kind: .effect, effectKind: .dodgeApplied, keyword: .dodge)
        ]
        for event in cases {
            XCTAssertNil(
                ActionEventFormatter.display(for: event).secondaryText,
                "secondaryText should be nil for \(event)"
            )
        }
    }
}
