import TrinketFeatureSupport
import XCTest

struct TabBar {
    let app: XCUIApplication

    func selectPlay() {
        app.buttons[AccessibilityID.Tab.play].trinketTapWhenReady()
    }

    func selectCollection() {
        app.buttons[AccessibilityID.Tab.collection].trinketTapWhenReady()
    }

    func selectHomestead() {
        app.buttons[AccessibilityID.Tab.homestead].trinketTapWhenReady()
    }

    func selectOptions() {
        app.buttons[AccessibilityID.Tab.options].trinketTapWhenReady()
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
