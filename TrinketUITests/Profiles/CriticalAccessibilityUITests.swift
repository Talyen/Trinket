import Synchronization
import TrinketFeatureSupport
import XCTest

final class CriticalAccessibilityUITests: FullGameStoreKitUITestCase {
    private static let originalReduceMotion = Mutex<Bool?>(nil)
    private static var settings: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    }

    override static func setUp() {
        super.setUp()
        settings.launch()
        defer { settings.terminate() }
        do {
            let control = reduceMotionControl()
            let original = try reduceMotionValue(control)
            originalReduceMotion.withLock { $0 = original }
            try setReduceMotion(ProcessInfo.processInfo.environment["TRINKET_PROFILE_REDUCE_MOTION"] == "1", control: control)
        } catch {
            XCTFail("Could not apply native Reduce Motion: \(error)")
        }
    }

    override static func tearDown() {
        defer { super.tearDown() }
        guard let original = originalReduceMotion.withLock({ value in
            defer { value = nil }
            return value
        }) else { return }
        settings.activate()
        defer { settings.terminate() }
        do {
            try setReduceMotion(original, control: reduceMotionControl())
        } catch {
            XCTFail("Could not restore native Reduce Motion: \(error)")
        }
    }

    private static func reduceMotionControl() -> XCUIElement {
        let control = settings.switches["Reduce Motion"].firstMatch
        if control.exists {
            revealSettingsElement(control, scrolling: settings)
            return control
        }
        let accessibility = settings.staticTexts["Accessibility"].firstMatch
        let sidebar = settings.collectionViews["com.apple.settings.sidebar.collectionView"].firstMatch
        if !sidebar.exists {
            for _ in 0 ..< 4 {
                if accessibility.exists {
                    break
                }
                let back = settings.navigationBars.buttons.element(boundBy: 0)
                if back.exists {
                    back.tap()
                }
            }
        }
        revealSettingsElement(accessibility, scrolling: sidebar.exists ? sidebar : settings)
        accessibility.trinketTapWhenReady()
        let motion = settings.staticTexts["Motion"].firstMatch
        revealSettingsElement(motion, scrolling: settings)
        motion.trinketTapWhenReady()
        XCTAssertTrue(control.trinketWaitForExistence(timeout: TrinketUITestCase.defaultTimeout))
        revealSettingsElement(control, scrolling: settings)
        return control
    }

    private static func revealSettingsElement(_ element: XCUIElement, scrolling container: XCUIElement) {
        for _ in 0 ..< 10 {
            if element.exists, element.isHittable {
                return
            }
            container.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Requested native setting is not reachable")
    }

    private static func reduceMotionValue(_ control: XCUIElement) throws -> Bool {
        let value = try XCTUnwrap(control.value as? String)
        XCTAssertTrue(value == "0" || value == "1", "Native Reduce Motion value unavailable: \(value)")
        return value == "1"
    }

    private static func setReduceMotion(_ enabled: Bool, control: XCUIElement) throws {
        if try reduceMotionValue(control) != enabled {
            control.trinketTapWhenReady()
        }
        XCTAssertTrue(trinketWaitUntil(timeout: TrinketUITestCase.defaultTimeout) {
            control.value as? String == (enabled ? "1" : "0")
        }, "Native Reduce Motion must match the requested setting")
    }

    func testCriticalControlsWithRequestedAccessibilityEnvironment() throws {
        try skipUnavailablePurchaseAutomation()
        try startStoreSession()
        let args = TestLaunchArg.productionTiming() + ["-coverage-diagnostics"]
        launchApp(arguments: args)
        try assertRequestedEnvironment()
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        let card = battle.handCards.firstMatch
        assertExists(card)
        card.press(forDuration: 0.7)
        assertExists(AccessibilityID.Battle.abilityDetail)
        try auditProductAccessibility()
        retainScreenshot(named: "card-inspection")
        dismissSheet(AccessibilityID.Battle.abilityDetail)
        tapWhenReady(battle.handCards.firstMatch)
        battle.openActions()
        tapButton(AccessibilityID.Battle.retreat)
        assertExists(AccessibilityID.Battle.defeat)
        try auditProductAccessibility()
        retainScreenshot(named: "defeat-leave")
        tapButton(AccessibilityID.Battle.defeatLeaveButton)
        play.assertCampaignLoaded()
        tabBar.selectHomestead()
        try verifyWheatFieldUpgrade(relaunch: false, audit: true)
        tapButton(AccessibilityID.Homestead.backButton)
        tabBar.selectOptions()
        assertExistsAfterScroll(AccessibilityID.FullGame.restore, requireHittable: true)
        tapButton(AccessibilityID.FullGame.restore)
        waitUntil("Restore must leave a usable control") { self.button(AccessibilityID.FullGame.restore).isEnabled }
        tapButton(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
        try auditProductAccessibility()
        retainScreenshot(named: "purchase-entry")
        dismissSheet(AccessibilityID.FullGame.offer)
    }

    func testRewardClaimRemainsReachableAndReturnsUnderRequestedSettings() throws {
        launchApp(arguments: TestLaunchArg.productionTiming()
            + TestLaunchArg.screen("battle-victory") + ["-coverage-diagnostics"])
        try assertRequestedEnvironment()
        assertExists(AccessibilityID.Battle.victory)
        assertExistsAfterScroll(AccessibilityID.Battle.continueButton, requireHittable: true)
        try auditProductAccessibility()
        retainScreenshot(named: "reward-claim")
        tapButton(AccessibilityID.Battle.continueButton)
        play.assertCampaignLoaded()
        XCTAssertTrue(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2)).isEnabled)
    }

    private func assertRequestedEnvironment() throws {
        let large = ProcessInfo.processInfo.environment["TRINKET_PROFILE_LARGE_TEXT"] == "1"
        let reduced = ProcessInfo.processInfo.environment["TRINKET_PROFILE_REDUCE_MOTION"] == "1"
        let environment = try coverageReport()
        XCTAssertEqual(environment["largeText"] as? Bool, large, "Native text-size setting did not reach SwiftUI")
        XCTAssertEqual(environment["largestText"] as? Bool, large)
        XCTAssertEqual(environment["reduceMotion"] as? Bool, reduced)
    }
}
