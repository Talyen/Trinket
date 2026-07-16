import XCTest

struct TabBar {
    let app: XCUIApplication

    func selectPlay() {
        app.tabBars.buttons["Play"].tap()
    }

    func selectCollection() {
        app.tabBars.buttons["Collection"].tap()
    }

    func selectHomestead() {
        app.tabBars.buttons["Homestead"].tap()
    }

    func selectOptions() {
        app.tabBars.buttons["Options"].tap()
    }
}

struct HomesteadScreen {
    let app: XCUIApplication

    func assertLoaded(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Screen.homestead]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Homestead screen not found", file: file, line: line)
    }

    func openNode(named title: String) {
        let node = app.descendants(matching: .any)[AccessibilityID.Homestead.node(title: title)]
        // Cinematic overview hero pushes the first project rows below the fold on
        // compact phones — scroll until the row is hittable before tapping.
        for _ in 0 ..< 6 where !(node.exists && node.isHittable) {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.90))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            start.press(forDuration: 0.05, thenDragTo: end)
            _ = node.waitForExistence(timeout: 0.15)
        }
        XCTAssertTrue(
            node.waitForExistence(timeout: TrinketUITestCase.defaultTimeout),
            "Homestead node '\(title)' not found"
        )
        if node.isHittable {
            node.tap()
        } else {
            node.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    func assertNodeDetail(
        named title: String,
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Homestead.nodeDetail(title: title)]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(title) homestead detail not found", file: file, line: line)
    }
}

struct OptionsScreen {
    let app: XCUIApplication

    func assertLoaded(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Screen.options]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Options screen not found", file: file, line: line)
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
