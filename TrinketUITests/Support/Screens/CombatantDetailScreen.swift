import XCTest

struct CombatantDetailScreen {
    let app: XCUIApplication

    func header(for name: String) -> XCUIElement {
        app.descendants(matching: .any)["\(name) detail hero header"]
    }

    func assertLoaded(for name: String, timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) {
        let element = header(for: name)
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(name) detail header not found", file: file, line: line)
    }

    func assertSections(timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) {
        let stats = app.descendants(matching: .any)[AccessibilityID.CombatantDetail.statsSection]
        XCTAssertTrue(stats.waitForExistence(timeout: timeout), "Combatant stats section not found", file: file, line: line)
        let health = app.descendants(matching: .any)[AccessibilityID.CombatantDetail.healthStat]
        XCTAssertTrue(health.waitForExistence(timeout: timeout), "Combatant health stat not found", file: file, line: line)
    }
}
