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
            NSPredicate(format: "identifier BEGINSWITH %@", "Battle Hand Card "),
        )
    }

    var actionsMenu: XCUIElement {
        app.buttons[AccessibilityID.Battle.actionsMenu]
    }

    var autoBattleToggle: XCUIElement {
        app.buttons[AccessibilityID.Battle.autoBattleToggle]
    }

    var retreatAction: XCUIElement {
        app.buttons[AccessibilityID.Battle.retreat]
    }

    var retreatConfirmAction: XCUIElement {
        app.buttons[AccessibilityID.Battle.retreatConfirm].firstMatch
    }

    func assertActive(
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let handChrome = app.descendants(matching: .any)
            .matching(identifier: AccessibilityID.Battle.hand)
            .firstMatch
        XCTAssertTrue(
            handChrome.trinketWaitForExistence(timeout: timeout),
            "Battle hand chrome not found",
            file: file,
            line: line,
        )
    }

    func openCombatantCard(named name: String) {
        app.buttons[AccessibilityID.CombatantDetail.battleCard(name: name)].tap()
    }

    func openActions() {
        actionsMenu.tap()
    }
}
