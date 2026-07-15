import XCTest

final class SmokeHeroDetailTests: TrinketUITestCase {
    func testHeroDetailOverscrollHeaderPreservation() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight")

        let header = combatantDetail.header(for: "Knight")
        assertExists(header)

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        start.press(forDuration: 0.1, thenDragTo: end)

        XCTAssertTrue(header.exists, "Hero header should still exist after overscroll")
    }

    func testHeroDetailEquipPersistsOnWeaponSlot() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight")

        scrollUntilVisible(button(AccessibilityID.Equipment.weaponSlot), swipingUp: true)
        button(AccessibilityID.Equipment.weaponSlot).tap()
        assertExists(AccessibilityID.LoadoutPicker.itemGrid("Weapon"))
        button(AccessibilityID.LoadoutPicker.itemCandidate("crossbow-basic")).tap()
        assertExists(AccessibilityID.LoadoutPicker.itemDetail("crossbow-basic"))
        button(AccessibilityID.LoadoutPicker.equipItem("crossbow-basic")).tap()

        assertButtonExists(AccessibilityID.Equipment.weaponSlot)
        assertExists("Crossbow")
    }
}
