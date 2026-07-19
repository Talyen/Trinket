import XCTest

struct CombatantDetailScreen {
    let app: XCUIApplication

    func header(for name: String) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.CombatantDetail.header(name: name)]
    }

    func assertLoaded(
        for name: String,
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = header(for: name)
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(name) detail header not found", file: file, line: line)
    }
}
