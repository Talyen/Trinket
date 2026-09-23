import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import XCTest

final class CollectionPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testCompanionDetail() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "collection"))
            reveal(button(AccessibilityID.CombatantDetail.collectionCard(name: "Wolf")))
            measured("companion-detail-navigation", iteration: iteration) {
                tapButton(AccessibilityID.CombatantDetail.collectionCard(name: "Wolf"))
                combatantDetail.assertLoaded(for: "Wolf")
            }
            let detailScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            performScrollGestures(app.scrollViews.firstMatch)
            verifyScrollProbes(detailScrollProbes, app.scrollViews.firstMatch)
            dismissSheet()
            assertDoesNotExist(AccessibilityID.CombatantDetail.vitalBarsSection)
        }
    }

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
            reveal(button(AccessibilityID.Equipment.basicAbilitySlot))
            measured("ability-picker", iteration: iteration) {
                tapButton(AccessibilityID.Equipment.basicAbilitySlot)
                assertExists(AccessibilityID.LoadoutPicker.abilityGrid("Basic"))
                tapButton(AccessibilityID.LoadoutPicker.abilityCandidate("block"))
                assertExists(AccessibilityID.LoadoutPicker.abilityDetail("block"))
                tapButton(AccessibilityID.LoadoutPicker.selectAbility("block"))
                assertDoesNotExist(AccessibilityID.LoadoutPicker.abilityGrid("Basic"))
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
            measured("equipment-inspect-equip", iteration: iteration) {
                tapButton(AccessibilityID.LoadoutPicker.itemCandidate("longsword-astral"))
                assertExists(AccessibilityID.LoadoutPicker.itemDetail("longsword-astral"))
                goBack()
                assertButtonExists(AccessibilityID.LoadoutPicker.itemCandidate("longsword-astral"))
                tapButton(AccessibilityID.LoadoutPicker.itemCandidate("longsword-astral"))
                tapButton(AccessibilityID.LoadoutPicker.equipItem("longsword-astral"))
                assertDoesNotExist(AccessibilityID.LoadoutPicker.itemGrid("Weapon"))
            }
            measured("equipment-unequip", iteration: iteration) {
                tapButton(slot)
                tapButton(AccessibilityID.LoadoutPicker.itemCandidate("longsword-astral"))
                tapButton(AccessibilityID.LoadoutPicker.unequipItem)
                assertDoesNotExist(AccessibilityID.LoadoutPicker.itemGrid("Weapon"))
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
            let shelfScrollProbes = captureScrollProbes(horizontalScrollView, horizontal: true)
            let didScrollShelf = measured("collection-shelf-scroll", iteration: iteration) {
                performScrollGestures(horizontalScrollView, horizontal: true)
            }
            if didScrollShelf {
                verifyScrollProbes(shelfScrollProbes, horizontalScrollView, horizontal: true)
            }
            let categories = ["Heroes", "Companions", "Basic Gear", "Astral Gear", "Unique Gear", "Trinkets"]
            for category in categories {
                if !selected("collection-category-\(category)") {
                    continue
                }
                let identifier = "\(category) collection category"
                reveal(button(identifier))
                measured("collection-category-\(category)", iteration: iteration) {
                    tapButton(identifier)
                }
                let categoryScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
                performScrollGestures(app.scrollViews.firstMatch)
                verifyScrollProbes(categoryScrollProbes, app.scrollViews.firstMatch)
                goBack()
                collection.assertLoaded()
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
            let node = firstTree?.nodes.first { $0.row == 1 }
            XCTAssertNotNil(node)
            let control = button(AccessibilityID.CombatantDetail.talentsNode(id: node?.id ?? "missing-talent"))
            reveal(control)
            measured("talent-unlock", iteration: iteration) {
                tapWhenReady(control)
                reveal(button(AccessibilityID.CombatantDetail.talentsUnlockButton))
                tapButton(AccessibilityID.CombatantDetail.talentsUnlockButton)
                assertExists(AccessibilityID.CombatantDetail.talentsResetButton)
            }
            measured("talent-reset-return", iteration: iteration) {
                tapButton(AccessibilityID.CombatantDetail.talentsResetButton)
                assertDoesNotExist(AccessibilityID.CombatantDetail.talentsResetButton)
                goBack()
                assertExists(AccessibilityID.CombatantDetail.talentsSection)
            }
        }
    }
}
