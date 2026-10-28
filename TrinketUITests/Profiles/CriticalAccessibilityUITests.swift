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
            defer { settings.terminate() }
            do {
                let control = try reduceMotionControl()
                let original = try reduceMotionValue(control)
                originalReduceMotion.withLock { $0 = original }
                try setReduceMotion(ProcessInfo.processInfo.environment["TRINKET_PROFILE_REDUCE_MOTION"] == "1")
            } catch {
                retainSettingsFailure(error, phase: "apply")
                preparationFailure.withLock { $0 = "[coverage prerequisite] Could not apply native Reduce Motion: \(error)" }
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
            defer { settings.terminate() }
            do {
                _ = try reduceMotionControl()
                try setReduceMotion(original)
            } catch {
                retainSettingsFailure(error, phase: "restore")
                XCTFail("[coverage prerequisite] Could not restore native Reduce Motion: \(error)")
            }
        }
    }

    @MainActor private static var reduceMotionSwitch: XCUIElement {
        settings.switches.matching(NSPredicate(
            format: "identifier IN %@ OR label BEGINSWITH %@", ["ReduceMotion", "Reduce Motion"], "Reduce Motion",
        )).firstMatch
    }

    @MainActor private static func retainSettingsFailure(_ error: Error, phase: String) {
        XCTContext.runActivity(named: "Native settings prerequisite: \(phase)") { activity in
            let details = "\(error)\nRuntime: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
                + "Profile: \(ProcessInfo.processInfo.environment["TRINKET_PROFILE_NAME"] ?? "unspecified")\n"
                + settings.debugDescription
            let attachment = XCTAttachment(string: String(details.suffix(16000)))
            attachment.name = "native-settings-\(phase)"
            attachment.lifetime = .keepAlways
            activity.add(attachment)
            if settings.state == .runningForeground {
                let screenshot = XCTAttachment(screenshot: settings.screenshot())
                screenshot.name = "native-settings-\(phase)"
                screenshot.lifetime = .keepAlways
                activity.add(screenshot)
            }
        }
    }

    @MainActor private static func reduceMotionControl() throws -> XCUIElement {
        // Settings retains its previous pane across launches. Navigate from its
        // root/sidebar each time, rather than reusing a control from another pane.
        settings.terminate()
        settings.launch()
        let cancelSearch = settings.buttons["Cancel"].firstMatch
        if settings.searchFields.firstMatch.exists, cancelSearch.exists {
            cancelSearch.tap()
        }
        let sidebar = settings.collectionViews["com.apple.settings.sidebar.collectionView"].firstMatch
        let accessibilityButton = settings.buttons["com.apple.settings.accessibility"].firstMatch
        let accessibilityCell = settings.cells.containing(.staticText, identifier: "Accessibility").firstMatch
        if !sidebar.exists {
            for _ in 0 ..< 6 {
                if accessibilityButton.exists || accessibilityCell.exists,
                   !settings.navigationBars["Accessibility"].exists {
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
        let motionButton = settings.buttons["MOTION_TITLE"].firstMatch
        if motionButton.exists {
            try revealSettingsElement(motionButton, scrolling: settingsContent())
            motionButton.tap()
        } else {
            motion.tap()
        }
        guard reduceMotionSwitch.trinketWaitForExistence(timeout: TrinketUITestCase.defaultTimeout) else {
            throw NativeSettingsFailure(
                description: "Reduce Motion switch missing after opening Motion. \(settings.debugDescription.suffix(10000))",
            )
        }
        try revealSettingsElement(reduceMotionSwitch, scrolling: settingsContent())
        return reduceMotionSwitch
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
            // A partially clipped Settings row can be reported hittable even
            // though its tap lands under the bottom system inset at large text sizes.
            let visibleFrame = container.frame.insetBy(dx: 0, dy: 44)
            if element.exists, element.isHittable,
               visibleFrame.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)),
               element.frame.minY >= visibleFrame.minY, element.frame.maxY <= visibleFrame.maxY {
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

    @MainActor private static func setReduceMotion(_ enabled: Bool) throws {
        if try reduceMotionValue(reduceMotionSwitch) != enabled {
            reduceMotionSwitch.tap()
        }
        guard trinketWaitUntil(timeout: TrinketUITestCase.defaultTimeout, condition: {
            reduceMotionSwitch.value as? String == (enabled ? "1" : "0")
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
        let card = battle.frontmostHandCard
        assertExists(card)
        card.press(forDuration: 0.7)
        assertExists(AccessibilityID.Battle.abilityDetail)
        try auditProductAccessibility(screen: "card-inspection")
        retainScreenshot(named: "card-inspection")
        dismissSheet(AccessibilityID.Battle.abilityDetail)
        let playedCard = battle.frontmostHandCard
        let playedID = playedCard.identifier
        XCTAssertFalse(playedID.isEmpty, "The card-play check must target an actual hand card")
        tapWhenReady(playedCard)
        waitUntil("Card play must remain usable under the requested settings") {
            !self.battle.handCards.matching(identifier: playedID).firstMatch.exists
        }
        battle.openActions()
        tapButton(AccessibilityID.Battle.retreat)
        assertExists(AccessibilityID.Battle.defeat)
        reveal(button(AccessibilityID.Battle.defeatLeaveButton))
        try auditProductAccessibility(screen: "defeat-leave")
        // Native Dynamic Type audits can change the scroll position while exercising sizes.
        reveal(button(AccessibilityID.Battle.defeatLeaveButton))
        retainScreenshot(named: "defeat-leave")
        tapButton(AccessibilityID.Battle.defeatLeaveButton)
        play.assertCampaignLoaded()
        tabBar.select(.homestead)
        try verifyWheatFieldUpgrade(audit: true)
        tapButton(AccessibilityID.Homestead.backButton)
        tabBar.select(.options)
        tapButtonAfterScroll(AccessibilityID.FullGame.restore)
        waitUntil("Restore must leave a usable control") { self.button(AccessibilityID.FullGame.restore).isEnabled }
        tapButton(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
        try auditProductAccessibility(screen: "purchase-entry")
        retainScreenshot(named: "purchase-entry")
        dismissSheet(AccessibilityID.FullGame.offer)
    }

    func testRewardClaimRemainsReachableAndReturnsUnderRequestedSettings() throws {
        launchApp(arguments: TestLaunchArg.productionTiming()
            + TestLaunchArg.screen("battle-victory") + ["-coverage-diagnostics"])
        try assertRequestedEnvironment()
        assertExists(AccessibilityID.Battle.victory)
        reveal(button(AccessibilityID.Battle.continueButton))
        try auditProductAccessibility(screen: "reward-claim")
        reveal(button(AccessibilityID.Battle.continueButton))
        retainScreenshot(named: "reward-claim")
        tapButton(AccessibilityID.Battle.continueButton)
        play.assertCampaignLoaded()
        tapButtonAfterScroll(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        assertExists(AccessibilityID.Mystery.encounterTitle)
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
            throw NativeSettingsFailure(description: "[coverage prerequisite] Native settings did not reach SwiftUI: \(environment)")
        }
    }
}
