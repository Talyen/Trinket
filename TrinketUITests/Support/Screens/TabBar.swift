import TrinketFeatureSupport
import XCTest

struct TabBar {
    let app: XCUIApplication

    func selectPlay() {
        app.tabBars.buttons[AccessibilityID.Tab.play].tap()
    }

    func selectCollection() {
        app.tabBars.buttons[AccessibilityID.Tab.collection].tap()
    }

    func selectHomestead() {
        app.tabBars.buttons[AccessibilityID.Tab.homestead].tap()
    }

    func selectOptions() {
        app.tabBars.buttons[AccessibilityID.Tab.options].tap()
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
        _ = categoryButton.trinketWaitForExistence(timeout: TrinketUITestCase.defaultTimeout)
        if categoryButton.isHittable {
            categoryButton.tap()
        } else {
            categoryButton.coordinate(withNormalizedOffset: CGVector(
                dx: 0.5,
                dy: 0.5,
            )).tap()
        }
        _ = app.descendants(matching: .any)[AccessibilityID.Homestead.node(title: "Wheat Field")]
            .trinketWaitForExistence(timeout: 2)
        app.scrollUntilVisible(
            app.descendants(matching: .any)[AccessibilityID.Homestead.node(title: "Wheat Field")],
            swipingUp: true,
            maxAttempts: 12,
        )
    }
}

struct OptionsScreen {
    let app: XCUIApplication

    func assertLoaded(
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Screen.options]
        XCTAssertTrue(element.trinketWaitForExistence(timeout: timeout), "Options screen not found", file: file, line: line)
    }
}
