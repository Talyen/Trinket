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
}
