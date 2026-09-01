import TrinketFeatureSupport
import XCTest

struct CombatantDetailScreen {
    let app: XCUIApplication

    func header(for name: String) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityID.CombatantDetail.header(name: name)]
    }

    func assertLoaded(
        for name: String,
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = header(for: name)
        XCTAssertTrue(element.trinketWaitForExistence(timeout: timeout), "\(name) detail header not found", file: file, line: line)
    }
}
