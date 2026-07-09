import XCTest

struct CollectionScreen {
    let app: XCUIApplication

    func assertLoaded(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.buttons[AccessibilityID.Collection.heroesCategory]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Collection screen not found", file: file, line: line)
    }

    func openHeroesCategory() {
        app.buttons[AccessibilityID.Collection.heroesCategory].tap()
    }

    func openPetsCategory() {
        app.buttons[AccessibilityID.Collection.petsCategory].tap()
    }

    func openInventoryCategory() {
        app.buttons[AccessibilityID.Collection.inventoryCategory].tap()
    }

    func openCombatantCard(named name: String) {
        app.buttons[AccessibilityID.CombatantDetail.collectionCard(name: name)].tap()
    }

    func openItemCard(named name: String) {
        app.buttons.matching(identifier: "\(name) item card").firstMatch.tap()
    }

    func filterInventory(to slot: String, file: StaticString = #filePath, line: UInt = #line) {
        let filterButton = app.buttons[AccessibilityID.Collection.inventoryFilter]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 2), "Inventory filter not found", file: file, line: line)
        filterButton.tap()
        let option = app.buttons[slot]
        XCTAssertTrue(option.waitForExistence(timeout: 2), "Inventory filter option '\(slot)' not found", file: file, line: line)
        option.tap()
    }

    var searchField: XCUIElement {
        app.searchFields.firstMatch
    }

    func assertSearchNoResults(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Collection.searchNoResults]
        let title = app.staticTexts["No Results Found"]
        let found = element.waitForExistence(timeout: timeout) || title.waitForExistence(timeout: timeout)
        XCTAssertTrue(
            found,
            "Collection search no-results state not found",
            file: file,
            line: line
        )
    }
}
