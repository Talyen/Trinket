import XCTest
@testable import Trinket

/// Locks the text format produced by `ActionEventFormatter.display(for:)`
/// so the view layer's floating-text chrome stays stable as the formatter
/// grows new emphasis categories.
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

    // MARK: - Ability damage

    func testAbilityDamageFormatsAsNegativeAmount() {
        let display = ActionEventFormatter.display(
            for: event(kind: .ability, amount: 3, keyword: .physical)
        )
        XCTAssertEqual(display.text, "-3")
        XCTAssertEqual(display.emphasis, .damage)
        XCTAssertEqual(display.keyword, .physical)
    }

    // MARK: - Status (DoT) damage

    func testStatusDamageFormatsAsNegativeWithKeyword() {
        let display = ActionEventFormatter.display(
            for: event(kind: .status, amount: 2, keyword: .burn)
        )
        XCTAssertEqual(display.text, "-2 Burn")
        XCTAssertEqual(display.emphasis, .status)
        XCTAssertEqual(display.keyword, .burn)
    }

    // MARK: - Restoration effects

    func testInstantHealFormatsAsPositiveWithKeyword() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .instantHeal, amount: 3, keyword: .health)
        )
        XCTAssertEqual(display.text, "+3 Health")
        XCTAssertEqual(display.emphasis, .heal)
    }

    func testResourceGainFormatsAsPositiveWithKeyword() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .resourceGain, amount: 1, keyword: .gold)
        )
        XCTAssertEqual(display.text, "+1 Gold")
        XCTAssertEqual(display.emphasis, .resourceGain)
    }

    func testLeechHealFormatsAsHeal() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .leechHeal, amount: 2, keyword: .health)
        )
        XCTAssertEqual(display.text, "+2 Health")
        XCTAssertEqual(display.emphasis, .heal)
    }

    // MARK: - Buff effects

    func testShieldAppliedFormatsAsBuff() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .shieldApplied, amount: 5, keyword: .block)
        )
        XCTAssertEqual(display.text, "+5 Block")
        XCTAssertEqual(display.emphasis, .buff)
    }

    func testMitigationAppliedFormatsAsPercent() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .mitigationApplied, amount: 25, keyword: .armor)
        )
        XCTAssertEqual(display.text, "+25% Armor")
        XCTAssertEqual(display.emphasis, .buff)
    }

    // MARK: - Damage absorbed

    func testShieldAbsorbedFormatsAsNegativeWithKeyword() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .shieldAbsorbed, amount: 3, keyword: .block)
        )
        XCTAssertEqual(display.text, "-3 Block")
        XCTAssertEqual(display.emphasis, .shieldAbsorbed)
    }

    // MARK: - Prevention

    func testPreventionSkippedFormatsAsKeyword() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .preventionSkipped, keyword: .stun)
        )
        XCTAssertEqual(display.text, "Stun")
        XCTAssertEqual(display.emphasis, .prevention)
    }

    func testPreventionAppliedFormatsAsPositiveKeyword() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .preventionApplied, keyword: .stun)
        )
        XCTAssertEqual(display.text, "+Stun")
        XCTAssertEqual(display.emphasis, .prevention)
    }

    func testPreventionTriggeredUsesStatusAlias() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .preventionTriggered, keyword: .stun)
        )
        XCTAssertEqual(display.text, "Stunned!")
        XCTAssertEqual(display.emphasis, .prevention)
    }

    func testPreventionTriggeredForFreezeUsesStatusAlias() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .preventionTriggered, keyword: .freeze)
        )
        XCTAssertEqual(display.text, "Frozen!")
    }

    // MARK: - Cleanse and dodge

    func testCleanseAppliedFormatsWithPrefix() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .cleanseApplied, keyword: .stun)
        )
        XCTAssertEqual(display.text, "Cleanse Stun")
        XCTAssertEqual(display.emphasis, .cleanse)
    }

    func testDodgeAppliedFormatsAsDodge() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: .dodgeApplied, keyword: .dodge)
        )
        XCTAssertEqual(display.text, "Dodge")
        XCTAssertEqual(display.emphasis, .dodge)
    }

    // MARK: - Edge cases

    func testEffectWithNilEffectKindFallsBackToKeyword() {
        let display = ActionEventFormatter.display(
            for: event(kind: .effect, effectKind: nil, keyword: .burn)
        )
        XCTAssertEqual(display.text, "Burn")
        XCTAssertEqual(display.emphasis, .generic)
    }

    func testSecondaryTextIsAlwaysNil() {
        // Locks the current contract: every event produces nil secondary
        // text. The field is reserved for future two-line presentations.
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
