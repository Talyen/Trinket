import TrinketFeatureSupport
import XCTest

struct ShopScreen {
    let app: XCUIApplication

    var offerCards: XCUIElementQuery {
        app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH %@", " shop offer"),
        )
    }

    var detailBuy: XCUIElement {
        app.buttons[AccessibilityID.Shop.detailBuyButton]
    }

    var leaveButton: XCUIElement {
        app.buttons[AccessibilityID.Shop.leaveButton]
    }

    func assertLoaded(
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = app.buttons[AccessibilityID.Shop.encounterTitle]
        XCTAssertTrue(element.trinketWaitForExistence(timeout: timeout), "Shop screen not found", file: file, line: line)
    }
}
