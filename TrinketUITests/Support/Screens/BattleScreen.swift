import XCTest

struct BattleScreen {
    let app: XCUIApplication

    var pauseButton: XCUIElement {
        app.buttons[AccessibilityID.Battle.pauseButton]
    }

    var menu: XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.Battle.menu]
    }

    var victory: XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.Battle.victory]
    }

    func assertActive(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            pauseButton.waitForExistence(timeout: timeout),
            "Battle pause control not found",
            file: file,
            line: line
        )
    }

    func openCombatantCard(named name: String) {
        app.buttons[AccessibilityID.CombatantDetail.battleCard(name: name)].tap()
    }

    func openMenu() {
        menu.tap()
    }

    func assertCombatLogVisible(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let log = app.descendants(matching: .any)[AccessibilityID.Battle.combatLog]
        XCTAssertTrue(log.waitForExistence(timeout: timeout), "Combat log not found", file: file, line: line)
    }

    func assertRetreatUnavailable(file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(
            app.buttons[AccessibilityID.Battle.retreat].exists,
            "Retreat should be unavailable after victory",
            file: file,
            line: line
        )
    }
}
