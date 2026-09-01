import TrinketFeatureSupport
import XCTest

struct CollectionScreen {
    let app: XCUIApplication

    func assertLoaded(
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Screen.collection]
        XCTAssertTrue(element.trinketWaitForExistence(timeout: timeout), "Collection screen not found", file: file, line: line)
    }
}
