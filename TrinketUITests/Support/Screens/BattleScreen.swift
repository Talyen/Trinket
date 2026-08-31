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

    var boonChoices: XCUIElementQuery {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Battle Boon "),
        )
    }

    var victory: XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.Battle.victory]
    }

    var actionsMenu: XCUIElement {
        app.buttons[AccessibilityID.Battle.actionsMenu]
    }

    var autoBattleToggle: XCUIElement {
        app.buttons[AccessibilityID.Battle.autoBattleToggle]
    }

    var combatLogAction: XCUIElement {
        app.buttons[AccessibilityID.Battle.combatLog]
    }

    var retreatAction: XCUIElement {
        app.buttons[AccessibilityID.Battle.retreat]
    }

    var retreatConfirmAction: XCUIElement {
        app.buttons[AccessibilityID.Battle.retreatConfirm].firstMatch
    }

    func assertPresented(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let handChrome = app.descendants(matching: .any)
            .matching(identifier: AccessibilityID.Battle.hand)
            .firstMatch
        if handChrome.waitForExistence(timeout: timeout) {
            return
        }
        XCTAssertTrue(
            victory.waitForExistence(timeout: 1),
            "Battle chrome not found",
            file: file,
            line: line,
        )
    }

    func assertActive(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let handChrome = app.descendants(matching: .any)
            .matching(identifier: AccessibilityID.Battle.hand)
            .firstMatch
        XCTAssertTrue(
            handChrome.waitForExistence(timeout: timeout),
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

    func selectFirstBoon(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let choice = boonChoices.firstMatch
        XCTAssertTrue(
            choice.waitForExistence(timeout: timeout),
            "Starting boon choice not found",
            file: file,
            line: line,
        )
        choice.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityID.Battle.boonChoice]
                .waitForNonExistence(timeout: timeout),
            "Starting boon choice did not dismiss",
            file: file,
            line: line,
        )
    }
}
