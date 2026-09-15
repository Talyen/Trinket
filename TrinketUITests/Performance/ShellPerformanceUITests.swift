import TrinketContent
import TrinketFeatureSupport
import XCTest

final class ShellPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testStarter() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: [TestLaunchArg.resetState, TestLaunchArg.disableCloudSync, TestLaunchArg.enableFrameMetrics])
            assertExists(AccessibilityID.Onboarding.heroScreen)
            let carouselProbes = captureScrollProbes(app.scrollViews.firstMatch, horizontal: true)
            measured("starter-carousel", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch, horizontal: true)
                app.buttons[AccessibilityID.Onboarding.option(role: .hero, combatantID: "knight")].tap()
            }
            verifyScrollProbes(carouselProbes, app.scrollViews.firstMatch, horizontal: true)
            measured("starter-hero-confirm", iteration: iteration, settle: 3) {
                tapWhenReady(any(AccessibilityID.Onboarding.confirm(role: .hero)))
                assertExists(AccessibilityID.Onboarding.companionScreen)
            }
            measured("starter-companion-confirm", iteration: iteration, settle: 3) {
                tapWhenReady(any(AccessibilityID.Onboarding.confirm(role: .companion)))
                play.assertLoaded()
            }
        }
    }

    @MainActor
    func testOptions() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "options"))
            options.assertLoaded()
            let optionsForm = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
            let optionsScrollProbes = captureScrollProbes(optionsForm)
            measured("options-controls", iteration: iteration) {
                app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 0.3)
                app.sliders.element(boundBy: 1).adjust(toNormalizedSliderPosition: 0.7)
                app.switches[AccessibilityID.Options.hapticsToggle].tap()
                app.switches[AccessibilityID.Options.rememberAutoBattleToggle].tap()
                performScrollGestures(app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch)
            }
            verifyScrollProbes(optionsScrollProbes, optionsForm)
            assertExistsAfterScroll(AccessibilityID.Options.resetProgressButton, requireHittable: true)
            measured("options-reset-cancel", iteration: iteration) {
                tapButton(AccessibilityID.Options.resetProgressButton)
                XCTAssertTrue(app.alerts.firstMatch.trinketWaitForExistence(timeout: 3))
                app.alerts.buttons.matching(identifier: AccessibilityID.Options.resetProgressCancel).firstMatch.tap()
                XCTAssertFalse(app.alerts.firstMatch.exists)
            }
            measured("options-reset-confirm", iteration: iteration) {
                tapButton(AccessibilityID.Options.resetProgressButton)
                tapWhenReady(app.alerts.buttons[AccessibilityID.Options.resetProgressConfirmation])
                assertExists(AccessibilityID.Onboarding.heroScreen)
            }
        }
    }

    @MainActor
    func testSalvage() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "collection"))
            let card = AccessibilityID.Collection.itemCard(itemID: "crossbow-basic")
            assertExistsAfterScroll(card, requireHittable: true)
            measured("salvage-return", iteration: iteration, settle: 2) {
                tapButton(card)
                assertExists(AccessibilityID.LoadoutPicker.itemDetail("crossbow-basic"))
                assertExistsAfterScroll(AccessibilityID.Collection.salvageButton, requireHittable: true)
                tapButton(AccessibilityID.Collection.salvageButton)
                tapWhenReady(app.alerts.buttons.matching(identifier: AccessibilityID.Collection.salvageConfirmButton).firstMatch)
                assertDoesNotExist(AccessibilityID.LoadoutPicker.itemDetail("crossbow-basic"))
                assertDoesNotExist(card)
            }
        }
    }

    @MainActor
    func testSamplerDetectsStall() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance() + ["-frame-metrics-validation-stall"])
            measured("diagnostic-stall", iteration: iteration) { play.assertLoaded() }
            let value = any(AccessibilityID.Debug.frameMetrics).value as? String ?? ""
            let report = FramePacingReport.parseAccessibilityValue(value)
            XCTAssertGreaterThan(report?.maxFrameMs ?? 0, 80)
            XCTAssertGreaterThan(report?.severeStallCount ?? 0, 0)
        }
    }
}
