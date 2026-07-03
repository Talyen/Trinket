import XCTest

struct CollectionScreen {
    let app: XCUIApplication

    func assertLoaded(timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) {
        let element = app.buttons["Heroes collection category"]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Collection screen not found", file: file, line: line)
    }

    func openHeroesCategory() {
        app.buttons["Heroes collection category"].tap()
    }

    func openPetsCategory() {
        app.buttons["Pets collection category"].tap()
    }

    func openInventoryCategory() {
        app.buttons["Inventory collection category"].tap()
    }

    func openCombatantCard(named name: String) {
        app.buttons["\(name) collection card"].tap()
    }

    func openItemCard(named name: String) {
        app.buttons.matching(identifier: "\(name) item card").firstMatch.tap()
    }

    func filterInventory(to slot: String) {
        app.buttons["Inventory filter"].tap()
        app.buttons[slot].tap()
    }
}
