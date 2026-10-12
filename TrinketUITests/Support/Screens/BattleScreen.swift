import TrinketFeatureSupport
import XCTest

struct BattleScreen {
    let app: XCUIApplication

    var hand: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: AccessibilityID.Battle.hand)
            .firstMatch
    }

    var handCards: XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Battle.handCardPrefix),
        )
    }

    var actionsMenu: XCUIElement {
        app.buttons[AccessibilityID.Battle.actionsMenu]
    }

    var autoBattleToggle: XCUIElement {
        app.buttons[AccessibilityID.Battle.autoBattleToggle]
    }

    func assertActive(
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        XCTAssertTrue(
            hand.trinketWaitForExistence(timeout: timeout),
            "Battle hand chrome not found",
            file: file,
            line: line,
        )
    }

    func openCombatantCard(named name: String) {
        app.buttons[AccessibilityID.CombatantDetail.battleCard(name: name)].trinketTapWhenReady()
    }

    func openActions() {
        actionsMenu.trinketTapWhenReady()
    }
}
