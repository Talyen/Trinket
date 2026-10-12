import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import XCTest

final class CollectionPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testDetailAndAbility() throws {
        try XCTSkipUnless(selected("combatant-detail-scroll"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allForScreen("hero:knight")))
            combatantDetail.assertLoaded(for: "Knight")
            measured("combatant-detail-scroll", iteration: iteration, scrolling: app.scrollViews.firstMatch)
        }
    }

    @MainActor
    func testEquipment() throws {
        try XCTSkipUnless(selected("equipment-picker-scroll") || selected("equipment-search-filter"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allForScreen("hero:knight")))
            combatantDetail.assertLoaded(for: "Knight")
            let slot = ItemSlot.weapon.accessibilityIdentifier
            reveal(button(slot))
            tapButton(slot)
            assertExists(AccessibilityID.LoadoutPicker.itemGrid("Weapon"))
            measured("equipment-picker-scroll", iteration: iteration, scrolling: app.scrollViews.firstMatch)
            guard selected("equipment-search-filter") else { continue }
            measured("equipment-search-filter", iteration: iteration) {
                tapButton(AccessibilityID.LoadoutPicker.itemFilter)
                tapButton(AccessibilityID.LoadoutPicker.itemRarityFilter)
                app.buttons["Astral"].tap()
                let search = app.searchFields.firstMatch
                XCTAssertTrue(search.trinketWaitForExistence(timeout: 5))
                replaceText(in: search, with: "long")
                assertExists(button(AccessibilityID.LoadoutPicker.itemCandidate("longsword-astral")))
                search.typeText("\n")
                XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
            }
        }
    }

    @MainActor
    func testCollectionBrowsing() throws {
        try XCTSkipUnless(selected("collection-browse-scroll"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "collection"))
            collection.assertLoaded()
            measured("collection-browse-scroll", iteration: iteration, scrolling: app.scrollViews.firstMatch)
        }
    }

    @MainActor
    func testTalents() throws {
        try XCTSkipUnless(selected("talent-tree-scroll"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg
                .performanceArguments(from: TestLaunchArg.allForScreen("hero:knight")) + ["-performance-talent-point"])
            combatantDetail.assertLoaded(for: "Knight")
            let config = CombatantTalentCatalog.config(for: "knight")
            let firstTree = config.trees.first
            XCTAssertNotNil(firstTree)
            let tree = app.buttons.containing(
                .staticText,
                identifier: AccessibilityID.CombatantDetail.talentsNode(id: firstTree?.keyword.rawValue ?? "missing-tree"),
            ).firstMatch
            reveal(tree)
            tapWhenReady(tree)
            measured("talent-tree-scroll", iteration: iteration, scrolling: app.scrollViews.firstMatch)
        }
    }
}
