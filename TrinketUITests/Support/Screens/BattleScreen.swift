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

    var ultimateCinematic: XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Ultimate Cinematic")
        ).firstMatch
    }

    func assertPresented(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Battle Menu stays in the toolbar for the whole cover (including victory/defeat).
        XCTAssertTrue(
            menu.waitForExistence(timeout: timeout),
            "Battle chrome not found",
            file: file,
            line: line
        )
    }

    func assertActive(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Pause is only present during active combat — do not fall back to menu (also on victory).
        let pause = app.descendants(matching: .any)[AccessibilityID.Battle.pauseButton]
        XCTAssertTrue(
            pause.waitForExistence(timeout: timeout),
            "Battle pause control not found",
            file: file,
            line: line
        )
    }

    /// Waits for mid-battle combatant chrome, or returns `true` if the battle already resolved.
    /// Skips Ultimate cinematics when present so matched-geometry expand does not hide cards.
    func waitForMidBattleOrVictory(
        combatantName: String = "Knight",
        timeout: TimeInterval = 8
    ) -> Bool {
        let card = app.descendants(matching: .any)[AccessibilityID.CombatantDetail.battleCard(name: combatantName)]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if victory.exists { return true }
            if ultimateCinematic.exists {
                // Default skip policy is `.always` in tests; tap to dismiss the overlay.
                ultimateCinematic.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                _ = ultimateCinematic.waitForNonExistence(timeout: 3)
                continue
            }
            if card.exists { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return victory.exists || !card.exists
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
