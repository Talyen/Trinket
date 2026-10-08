import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import XCTest

final class CollectionPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testDetailAndAbility() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allForScreen("hero:knight")))
            combatantDetail.assertLoaded(for: "Knight")
            let detailScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            let didScroll = measured("combatant-detail-scroll", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch)
            }
            if didScroll {
                verifyScrollProbes(detailScrollProbes, app.scrollViews.firstMatch)
            }
        }
    }

    @MainActor
    func testEquipment() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allForScreen("hero:knight")))
            combatantDetail.assertLoaded(for: "Knight")
            let slot = ItemSlot.weapon.accessibilityIdentifier
            reveal(button(slot))
            tapButton(slot)
            assertExists(AccessibilityID.LoadoutPicker.itemGrid("Weapon"))
            let pickerScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            let didScroll = measured("equipment-picker-scroll", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch)
            }
            if didScroll {
                verifyScrollProbes(pickerScrollProbes, app.scrollViews.firstMatch)
            }
            measured("equipment-search-filter", iteration: iteration) {
                tapButton(AccessibilityID.LoadoutPicker.itemFilter)
                tapButton(AccessibilityID.LoadoutPicker.itemRarityFilter)
                app.buttons["Astral"].tap()
                let search = app.searchFields.firstMatch
                XCTAssertTrue(search.trinketWaitForExistence(timeout: 5))
                replaceText(in: search, with: "long")
                assertButtonExists(AccessibilityID.LoadoutPicker.itemCandidate("longsword-astral"))
                search.typeText("\n")
                XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
            }
        }
    }

    @MainActor
    func testCollectionBrowsing() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "collection"))
            collection.assertLoaded()
            let browseScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            let didBrowse = measured("collection-browse-scroll", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch)
            }
            if didBrowse {
                verifyScrollProbes(browseScrollProbes, app.scrollViews.firstMatch)
            }
        }
    }

    @MainActor
    func testTalents() {
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
            let talentScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            let didScroll = measured("talent-tree-scroll", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch)
            }
            if didScroll {
                verifyScrollProbes(talentScrollProbes, app.scrollViews.firstMatch)
            }
        }
    }
}
