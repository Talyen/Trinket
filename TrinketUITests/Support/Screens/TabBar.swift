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

    func selectSearch() {
        app.tabBars.buttons["Search"].tap()
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
        app.descendants(matching: .any)[AccessibilityID.Homestead.node(title: title)].tap()
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

struct SearchScreen {
    let app: XCUIApplication

    func assertEmptyState(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Search.emptyState]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Search empty state not found", file: file, line: line)
    }

    func assertNoResults(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Search.noResults]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Search no-results state not found", file: file, line: line)
    }

    var searchField: XCUIElement {
        app.searchFields.firstMatch
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
}
