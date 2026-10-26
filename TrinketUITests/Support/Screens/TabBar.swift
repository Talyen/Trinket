import TrinketAppState
import TrinketContent
import TrinketFeatureSupport
import XCTest

struct TabBar {
    let app: XCUIApplication

    func button(for tab: AppTab, locale: Locale = .current) -> XCUIElement {
        let title = ContentCopy.localized(tab.displayName, locale: locale)
        let standardTab = app.tabBars.buttons[title]
        if standardTab.exists {
            return standardTab
        }
        // Duo exposes tabs as toolbar buttons; a Back button can share the label.
        return app.buttons.matching(NSPredicate(
            format: "label == %@ AND identifier != %@", title, "BackButton",
        )).firstMatch
    }

    func select(_ tab: AppTab, locale: Locale = .current) {
        button(for: tab, locale: locale).trinketTapWhenReady()
    }
}

struct HomesteadScreen {
    let app: XCUIApplication

    func assertLoaded(
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Screen.homestead]
        XCTAssertTrue(element.trinketWaitForExistence(timeout: timeout), "Homestead screen not found", file: file, line: line)
    }

    func assertNodeDetail(
        named title: String,
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Homestead.nodeDetail(title: title)]
        XCTAssertTrue(element.trinketWaitForExistence(timeout: timeout), "\(title) homestead detail not found", file: file, line: line)
    }

    func openFarmingCategoryAndRevealWheatFieldNode() {
        let categoryButton = app.buttons[AccessibilityID.Homestead.category("Farming")]
        guard app.scrollUntilVisible(categoryButton, swipingUp: true, maxAttempts: 12, requireHittable: true) else {
            XCTFail("Farming category must be reachable before opening its nodes")
            return
        }
        categoryButton.trinketTapWhenReady()
        _ = app.descendants(matching: .any)[AccessibilityID.Homestead.node(title: "Wheat Field")]
            .trinketWaitForExistence(timeout: 2)
        app.scrollUntilVisible(
            app.descendants(matching: .any)[AccessibilityID.Homestead.node(title: "Wheat Field")],
            swipingUp: true,
            maxAttempts: 12,
        )
    }
}
