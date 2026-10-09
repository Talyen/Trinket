import TrinketFeatureSupport
import XCTest

final class CriticalAccessibilityUITests: FullGameStoreKitUITestCase {
    private var originalReduceMotion: Bool?
    private var settings: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        settings.launch()
        let control = reduceMotionControl()
        originalReduceMotion = try reduceMotionValue(control)
        try setReduceMotion(ProcessInfo.processInfo.environment["TRINKET_PROFILE_REDUCE_MOTION"] == "1")
        settings.terminate()
    }

    override func tearDownWithError() throws {
        var restorationFailure: (any Error)?
        do {
            if let originalReduceMotion {
                settings.activate()
                defer { settings.terminate() }
                try setReduceMotion(originalReduceMotion)
            }
        } catch {
            restorationFailure = error
        }
        try super.tearDownWithError()
        if let restorationFailure {
            throw restorationFailure
        }
    }

    private func reduceMotionControl() -> XCUIElement {
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
        tapWhenReady(accessibility)
        let motion = settings.staticTexts["Motion"].firstMatch
        revealSettingsElement(motion, scrolling: settings)
        tapWhenReady(motion)
        assertExists(control)
        revealSettingsElement(control, scrolling: settings)
        return control
    }

    private func revealSettingsElement(_ element: XCUIElement, scrolling container: XCUIElement) {
        for _ in 0 ..< 10 {
            if element.exists, element.isHittable {
                return
            }
            container.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Requested native setting is not reachable")
    }

    private func reduceMotionValue(_ control: XCUIElement) throws -> Bool {
        let value = try XCTUnwrap(control.value as? String)
        XCTAssertTrue(value == "0" || value == "1", "Native Reduce Motion value unavailable: \(value)")
        return value == "1"
    }

    private func setReduceMotion(_ enabled: Bool) throws {
        let control = reduceMotionControl()
        if try reduceMotionValue(control) != enabled {
            tapWhenReady(control)
        }
        waitUntil("Native Reduce Motion must match the requested setting") {
            control.value as? String == (enabled ? "1" : "0")
        }
    }

    func testCriticalControlsWithRequestedAccessibilityEnvironment() throws {
        try skipUnavailablePurchaseAutomation()
        try startStoreSession()
        let args = TestLaunchArg.productionTiming() + ["-coverage-diagnostics"]
        let large = ProcessInfo.processInfo.environment["TRINKET_PROFILE_LARGE_TEXT"] == "1"
        let reduced = ProcessInfo.processInfo.environment["TRINKET_PROFILE_REDUCE_MOTION"] == "1"
        launchApp(arguments: args)
        let probe = any(AccessibilityID.Debug.coverageDiagnostics)
        assertExists(probe)
        let environment = try coverageReport()
        XCTAssertEqual(environment["largeText"] as? Bool, large, "Native text-size setting did not reach SwiftUI")
        XCTAssertEqual(environment["largestText"] as? Bool, large)
        XCTAssertEqual(environment["reduceMotion"] as? Bool, reduced)
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
        let args = TestLaunchArg.productionTiming() + ["-performance-strong-party"]
        launchApp(arguments: args)
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        tapWhenReady(battle.autoBattleToggle)
        assertExists(AccessibilityID.Battle.victory, timeout: 30)
        assertExistsAfterScroll(AccessibilityID.Battle.continueButton, requireHittable: true)
        try auditProductAccessibility()
        retainScreenshot(named: "reward-claim")
        tapButton(AccessibilityID.Battle.continueButton)
        play.assertCampaignLoaded()
        XCTAssertTrue(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2)).isEnabled)
    }
}
