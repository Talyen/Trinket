import XCTest

struct BattleScreen {
    let app: XCUIApplication

    var hand: XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.Battle.hand]
    }

    var victory: XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.Battle.victory]
    }

    var actionsMenu: XCUIElement {
        app.buttons[AccessibilityID.Battle.actionsMenu]
    }

    var combatLogAction: XCUIElement {
        app.buttons[AccessibilityID.Battle.combatLog]
    }

    var retreatAction: XCUIElement {
        app.buttons[AccessibilityID.Battle.retreat]
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
        // Active combat shows the hand; outcome screens show Victory chrome.
        let handChrome = app.descendants(matching: .any)[AccessibilityID.Battle.hand]
        if handChrome.waitForExistence(timeout: timeout) {
            return
        }
        XCTAssertTrue(
            victory.waitForExistence(timeout: 1),
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
        let handChrome = app.descendants(matching: .any)[AccessibilityID.Battle.hand]
        XCTAssertTrue(
            handChrome.waitForExistence(timeout: timeout),
            "Battle hand chrome not found",
            file: file,
            line: line
        )
    }

    /// Waits for mid-battle combatant chrome, or returns `true` if the battle already resolved.
    /// Skips Ultimate cinematics when present so matched-geometry expand does not hide cards.
    /// Fails (rather than silently skipping) when neither mid-battle chrome nor victory appears.
    func waitForMidBattleOrVictory(
        combatantName: String = "Ranger",
        timeout: TimeInterval = 8,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let card = app.descendants(matching: .any)[AccessibilityID.CombatantDetail.battleCard(name: combatantName)]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if victory.exists {
                return true
            }
            if ultimateCinematic.exists {
                // Default skip policy is `.always` in tests; tap to dismiss the overlay.
                ultimateCinematic.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                _ = ultimateCinematic.waitForNonExistence(timeout: 3)
                continue
            }
            if card.exists {
                return false
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        if victory.exists {
            return true
        }
        XCTAssertTrue(
            card.exists,
            "Neither mid-battle combatant card nor victory chrome appeared",
            file: file,
            line: line
        )
        return false
    }

    func openCombatantCard(named name: String) {
        app.buttons[AccessibilityID.CombatantDetail.battleCard(name: name)].tap()
    }

    func openActions() {
        actionsMenu.tap()
    }
}
