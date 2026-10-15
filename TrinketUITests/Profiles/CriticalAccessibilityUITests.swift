import Synchronization
import TrinketFeatureSupport
import XCTest

final class CriticalAccessibilityUITests: FullGameStoreKitUITestCase {
    private static let originalReduceMotion = Mutex<Bool?>(nil)
    private static let preparationFailure = Mutex<String?>(nil)

    private struct NativeSettingsFailure: Error, CustomStringConvertible {
        let description: String
    }

    @MainActor private static var settings: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    }

    override static func setUp() {
        super.setUp()
        preparationFailure.withLock { $0 = nil }
        trinketOnMainActor {
            settings.launch()
            defer { settings.terminate() }
            do {
                let control = try reduceMotionControl()
                let original = try reduceMotionValue(control)
                originalReduceMotion.withLock { $0 = original }
                try setReduceMotion(ProcessInfo.processInfo.environment["TRINKET_PROFILE_REDUCE_MOTION"] == "1", control: control)
            } catch {
                preparationFailure.withLock { $0 = "Could not apply native Reduce Motion: \(error)" }
            }
        }
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        if let failure = Self.preparationFailure.withLock({ $0 }) {
            throw NativeSettingsFailure(description: failure)
        }
    }

    override static func tearDown() {
        defer { super.tearDown() }
        guard let original = originalReduceMotion.withLock({ value in
            defer { value = nil }
            return value
        }) else { return }
        trinketOnMainActor {
            settings.activate()
            defer { settings.terminate() }
            do {
                try setReduceMotion(original, control: reduceMotionControl())
            } catch {
                XCTFail("Could not restore native Reduce Motion: \(error)")
            }
        }
    }

    @MainActor private static func reduceMotionControl() throws -> XCUIElement {
        let control = settings.switches.matching(NSPredicate(
            format: "identifier IN %@ OR label BEGINSWITH %@", ["ReduceMotion", "Reduce Motion"], "Reduce Motion",
        )).firstMatch
        if control.exists {
            try revealSettingsElement(control, scrolling: settingsContent())
            return control
        }
        let cancelSearch = settings.buttons["Cancel"].firstMatch
        if settings.searchFields.firstMatch.exists, cancelSearch.exists {
            cancelSearch.tap()
        }
        let sidebar = settings.collectionViews["com.apple.settings.sidebar.collectionView"].firstMatch
        let accessibilityButton = settings.buttons["com.apple.settings.accessibility"].firstMatch
        let accessibilityCell = settings.cells.containing(.staticText, identifier: "Accessibility").firstMatch
        if !sidebar.exists {
            for _ in 0 ..< 4 {
                if accessibilityButton.exists || accessibilityCell.exists {
                    break
                }
                let back = settings.navigationBars.buttons.matching(
                    NSPredicate(format: "label IN %@", ["Settings", "Accessibility", "Back"]),
                ).firstMatch
                guard back.exists else { break }
                back.tap()
            }
        }
        let accessibility = accessibilityButton.exists ? accessibilityButton : accessibilityCell
        try revealSettingsElement(accessibility, scrolling: sidebar.exists ? sidebar : settingsContent())
        accessibility.tap()
        let motionCell = settings.cells["MOTION_TITLE"].firstMatch
        let motion = motionCell.exists ? motionCell : settings.cells.containing(.staticText, identifier: "Motion").firstMatch
        try revealSettingsElement(motion, scrolling: settingsContent())
        motion.tap()
        guard control.trinketWaitForExistence(timeout: TrinketUITestCase.defaultTimeout) else {
            throw NativeSettingsFailure(
                description: "Reduce Motion switch missing after opening Motion. \(settings.debugDescription.suffix(10000))",
            )
        }
        try revealSettingsElement(control, scrolling: settingsContent())
        return control
    }

    @MainActor private static func settingsContent() -> XCUIElement {
        let sidebar = settings.collectionViews["com.apple.settings.sidebar.collectionView"].firstMatch
        let containers = settings.tables.allElementsBoundByIndex + settings.collectionViews.allElementsBoundByIndex
        // On iPad, scrolling the application can move the sidebar instead of the selected settings pane.
        if sidebar.exists, let detail = containers.first(where: { $0.frame.minX >= sidebar.frame.maxX - 1 }) {
            return detail
        }
        return containers.first(where: { $0.identifier != "com.apple.settings.sidebar.collectionView" }) ?? settings
    }

    @MainActor private static func revealSettingsElement(_ element: XCUIElement, scrolling container: XCUIElement) throws {
        for _ in 0 ..< 10 {
            if element.exists, element.isHittable, container.frame.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) {
                return
            }
            if element.exists, element.frame.midY < container.frame.midY {
                container.swipeDown()
            } else {
                container.swipeUp()
            }
        }
        throw NativeSettingsFailure(
            description: "Requested native setting is not reachable. Settings hierarchy: \(settings.debugDescription.suffix(10000))",
        )
    }

    @MainActor private static func reduceMotionValue(_ control: XCUIElement) throws -> Bool {
        let value = try XCTUnwrap(control.value as? String)
        guard value == "0" || value == "1" else {
            throw NativeSettingsFailure(description: "Native Reduce Motion value unavailable: \(value)")
        }
        return value == "1"
    }

    @MainActor private static func setReduceMotion(_ enabled: Bool, control: XCUIElement) throws {
        if try reduceMotionValue(control) != enabled {
            control.tap()
        }
        guard trinketWaitUntil(timeout: TrinketUITestCase.defaultTimeout, condition: {
            control.value as? String == (enabled ? "1" : "0")
        }) else {
            throw NativeSettingsFailure(description: "Native Reduce Motion did not match requested value \(enabled)")
        }
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
        assertExistsAfterScroll(AccessibilityID.Battle.defeatLeaveButton, requireHittable: true)
        try auditProductAccessibility()
        // Native Dynamic Type audits can change the scroll position while exercising sizes.
        assertExistsAfterScroll(AccessibilityID.Battle.defeatLeaveButton, requireHittable: true)
        retainScreenshot(named: "defeat-leave")
        tapButton(AccessibilityID.Battle.defeatLeaveButton)
        play.assertCampaignLoaded()
        tabBar.selectHomestead()
        try verifyWheatFieldUpgrade(audit: true)
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
        assertExistsAfterScroll(AccessibilityID.Battle.continueButton, requireHittable: true)
        retainScreenshot(named: "reward-claim")
        tapButton(AccessibilityID.Battle.continueButton)
        play.assertCampaignLoaded()
        XCTAssertTrue(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2)).isEnabled)
    }

    private func assertRequestedEnvironment() throws {
        let large = ProcessInfo.processInfo.environment["TRINKET_PROFILE_LARGE_TEXT"] == "1"
        let reduced = ProcessInfo.processInfo.environment["TRINKET_PROFILE_REDUCE_MOTION"] == "1"
        var environment = try coverageReport()
        guard trinketWaitUntil(timeout: Self.defaultTimeout, condition: {
            if let current = try? self.coverageReport() {
                environment = current
            }
            return environment["largeText"] as? Bool == large
                && environment["largestText"] as? Bool == large
                && environment["reduceMotion"] as? Bool == reduced
        }) else {
            throw NativeSettingsFailure(description: "Native settings did not reach SwiftUI: \(environment)")
        }
    }
}
