import TrinketContent
import TrinketFeatureSupport
import XCTest

final class SmokeShellTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("play")
    }

    func testSalvageReturnsToCollectionWithoutAnInteractiveRetiringItem() {
        tabBar.selectCollection()
        collection.assertLoaded(timeout: 10)
        salvageItem("crossbow-basic")
        scrollUntilVisible(button(AccessibilityID.Collection.basicGearCategory), swipingUp: false, requireHittable: true)
        tapButton(AccessibilityID.Collection.basicGearCategory)
        assertDoesNotExist(AccessibilityID.Collection.itemCard(itemID: "crossbow-basic"), timeout: 2)
        assertExistsAfterScroll(AccessibilityID.Collection.itemCard(itemID: "double_axe-basic"))
    }

    private func salvageItem(_ itemID: String) {
        let card = AccessibilityID.Collection.itemCard(itemID: itemID)
        let item = button(card)
        scrollUntilVisible(item, swipingUp: false, maxAttempts: 6, requireHittable: true)
        if !item.exists || !item.isHittable {
            scrollUntilVisible(item, swipingUp: true, maxAttempts: 3, requireHittable: true)
        }
        tapWhenReady(item)
        assertExists(AccessibilityID.LoadoutPicker.itemDetail(itemID))
        assertExistsAfterScroll(AccessibilityID.Collection.salvageButton, requireHittable: true)
        tapButton(AccessibilityID.Collection.salvageButton)
        tapWhenReady(app.alerts.buttons.matching(identifier: AccessibilityID.Collection.salvageConfirmButton).firstMatch)
        assertDoesNotExist(AccessibilityID.LoadoutPicker.itemDetail(itemID), timeout: 5)
        assertDoesNotExist(card, timeout: 5)
    }

    func testTabShellsAreReachable() {
        play.assertLoaded(timeout: 10)
        assertExists(AccessibilityID.Play.campaignModeCard, timeout: 10)
        assertExists(AccessibilityID.Play.exploreModeCard, timeout: 10)

        tabBar.selectCollection()
        collection.assertLoaded(timeout: 10)
        assertExists(AccessibilityID.Collection.heroesCategory, timeout: 10)
        assertExists(AccessibilityID.Collection.companionsCategory, timeout: 10)

        tabBar.selectHomestead()
        homestead.assertLoaded(timeout: 10)
        assertExists(AccessibilityID.Homestead.resourceWallet, timeout: 10)

        tabBar.selectOptions()
        options.assertLoaded(timeout: 10)
        assertExists(AccessibilityID.Options.hapticsToggle, timeout: 10)

        tabBar.selectPlay()
        play.assertLoaded(timeout: 10)
    }
}

final class StarterOnboardingSmokeTests: TrinketUITestCase {
    func testStarterRouletteLandsOnGameModeHub() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
        ])

        assertExists(AccessibilityID.Onboarding.heroScreen, timeout: 15)
        XCTAssertEqual(app.tabBars.count, 0)

        let heroConfirm = app.descendants(matching: .any)[AccessibilityID.Onboarding.confirm(role: .hero)]
        if !heroConfirm.trinketWaitForExistence(timeout: 15) {
            XCTFail("Confirm Hero not found. Tree: \(String(app.debugDescription.prefix(2500)))")
        }
        XCTAssertTrue(heroConfirm.isEnabled)
        XCTAssertNotEqual(heroConfirm.label.trimmingCharacters(in: .whitespacesAndNewlines), "Confirm Hero")
        tapWhenReady(heroConfirm)

        assertExists(AccessibilityID.Onboarding.companionScreen, timeout: 15)

        let companionConfirm = app.descendants(matching: .any)[AccessibilityID.Onboarding.confirm(role: .companion)]
        if !companionConfirm.trinketWaitForExistence(timeout: 15) {
            XCTFail("Confirm Companion not found. Tree: \(String(app.debugDescription.prefix(2500)))")
        }
        XCTAssertTrue(companionConfirm.isEnabled)
        XCTAssertNotEqual(companionConfirm.label.trimmingCharacters(in: .whitespacesAndNewlines), "Confirm Companion")
        tapWhenReady(companionConfirm)

        XCTAssertTrue(
            app.tabBars.firstMatch.trinketWaitForExistence(timeout: 15),
            "Tab bar did not appear after onboarding",
        )
        play.assertLoaded(timeout: 15)
    }
}
