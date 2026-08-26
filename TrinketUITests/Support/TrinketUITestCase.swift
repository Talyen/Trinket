import TrinketFeatureSupport
import XCTest

enum TestLaunchArg {
    static func tab(_ tab: String) -> String {
        "-selectedTab \(tab)"
    }

    static let resetState = "-reset-state"
    static let seedTestProgress = "-seed-test-progress"
    static let skipStarterSelection = "-skip-starter-selection"
    static let skipOnboardingCeremony = "-skip-onboarding-ceremony"
    static let disableCloudSync = "-disable-cloud-sync"
    static let testLaunchArgs = [
        resetState,
        seedTestProgress,
        disableCloudSync,
        "-disable-audio",
        "-persist-save-immediately",
        "-battle-tick-interval",
        "1.0",
    ]
    static func screen(_ screen: String) -> [String] {
        ["-launch-screen", screen]
    }

    /// Fresh-save base for journeys where seeded progress would skip content.
    static func allUnseeded() -> [String] {
        [
            resetState,
            disableCloudSync,
            skipStarterSelection,
            "-disable-audio",
            "-persist-save-immediately",
        ]
    }

    static func completedStages(_ stageIDs: [String]) -> [String] {
        ["-completed-stages", stageIDs.joined(separator: ",")]
    }

    static func mysteryRecruit(eventID: String) -> [String] {
        ["-mystery-recruit-event", eventID]
    }

    static func allForTab(_ tab: String, reset: Bool = true) -> [String] {
        var args = reset ? testLaunchArgs : []
        args.append(contentsOf: ["-selectedTab", tab])
        return args
    }

    /// Screen tokens must match `LaunchScreen.parse` in AppTypes.
    static func allForScreen(_ screen: String, reset: Bool = true) -> [String] {
        var args = reset ? testLaunchArgs : []
        args.append(contentsOf: self.screen(screen))
        return args
    }

    static func allForBattle(reset: Bool = true, fastTicks: Bool = false) -> [String] {
        var args = allForScreen("battle", reset: reset)
        if fastTicks {
            args += ["-battle-tick-interval", "0.01"]
        }
        return args
    }

    static let enableFrameMetrics = "-enable-frame-metrics"

    static func allForAppPerformance(tab: String = "play", reset: Bool = true) -> [String] {
        performanceArguments(from: allForTab(tab, reset: reset))
    }

    static func allForBattlePerformance(
        _ scenario: String,
        reset: Bool = true
    ) -> [String] {
        var args = performanceArguments(from: allForBattle(reset: reset))
        args += ["-battle-performance-scenario", scenario]
        if ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1" {
            args.append("-battle-performance-quick")
        }
        return args
    }

    static func allForVictoryPerformance(reset: Bool = true) -> [String] {
        performanceArguments(from: allForBattleVictory(reset: reset))
    }

    static func allForMysteryPerformance(reset: Bool = true) -> [String] {
        // Avoid seed-test-progress: seeded journeys can skip the mystery stage.
        // Force a recruit event so resolve never no-ops into stage completion.
        var args: [String] = []
        if reset {
            args += [
                resetState,
                disableCloudSync,
                skipStarterSelection,
                "-persist-save-immediately",
                "-battle-tick-interval",
                "1.0",
            ]
        }
        args += screen("mystery")
        args += completedStages(["chapter-1-stage-1"])
        args += mysteryRecruit(eventID: "recruit-bear")
        return performanceArguments(from: args)
    }

    static func performanceArguments(from arguments: [String]) -> [String] {
        var result = arguments
        // Performance runs exercise production audio. Cloud sync remains disabled because
        // unrelated network work would reduce local repeatability.
        result.removeAll { $0 == "-disable-audio" || $0 == enableFrameMetrics }
        result.append(enableFrameMetrics)
        return result
    }

    static func allForBattleVictory(reset: Bool = true) -> [String] {
        allForScreen("battle-victory", reset: reset)
    }

    /// Play-map mid-battle exhaustive entry. Very slow ticks keep the opening
    /// hand and combatant chrome reachable while XCTest opens the campaign and
    /// asserts card gestures without racing into live-tick resolution.
    static func allForMidBattle() -> [String] {
        replacingBattleTickInterval("60", in: testLaunchArgs)
    }

    static func allForShop(reset: Bool = true) -> [String] {
        allForScreen("shop", reset: reset)
    }

    static func replacingBattleTickInterval(_ interval: String, in args: [String]) -> [String] {
        var result = args
        if let index = result.firstIndex(of: "-battle-tick-interval"), index + 1 < result.count {
            result[index + 1] = interval
        } else {
            result += ["-battle-tick-interval", interval]
        }
        return result
    }
}

class TrinketUITestCase: XCTestCase {
    /// Deep-linked screens should appear quickly; keep failure waits short to cut flake wall time.
    static let defaultTimeout: TimeInterval = 3

    // IUO matches XCTest launch lifecycle: set in launchApp, cleared in tearDown.
    // swiftlint:disable:next implicitly_unwrapped_optional
    private(set) var app: XCUIApplication!

    var play: PlayScreen {
        PlayScreen(app: app)
    }

    var collection: CollectionScreen {
        CollectionScreen(app: app)
    }

    var combatantDetail: CombatantDetailScreen {
        CombatantDetailScreen(app: app)
    }

    var tabBar: TabBar {
        TabBar(app: app)
    }

    var homestead: HomesteadScreen {
        HomesteadScreen(app: app)
    }

    var options: OptionsScreen {
        OptionsScreen(app: app)
    }

    var battle: BattleScreen {
        BattleScreen(app: app)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if let app {
            app.terminate()
        }
        app = nil
        try super.tearDownWithError()
    }

    func launchApp(arguments: [String] = []) {
        app = XCUIApplication()
        var launchArgs = arguments
        launchArgs.append(contentsOf: ["-store-name", UUID().uuidString])
        app.launchArguments = launchArgs
        // Forward perf knobs into the app process (UITest env is not inherited by default).
        var launchEnvironment = app.launchEnvironment
        for key in ["TRINKET_PERFORMANCE_QUICK"] {
            if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
                launchEnvironment[key] = value
            }
        }
        app.launchEnvironment = launchEnvironment
        app.launch()
    }

    func button(_ identifier: String) -> XCUIElement {
        app.buttons[identifier]
    }

    func any(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Tap a button by accessibility id, waiting for hittability and falling back to a coordinate tap.
    func tapButton(
        _ identifier: String,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = button(identifier)
        guard element.waitForExistence(timeout: timeout) else {
            fail("Button '\(identifier)' not found", file: file, line: line)
            return
        }
        tapWhenReady(element)
    }

    func tapWhenReady(_ element: XCUIElement) {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, !element.isHittable {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Waits for an element to exist and become enabled (animated ceremonies
    /// unlock controls after they finish). Fails via XCTFail when it never does.
    @discardableResult
    func waitForEnabled(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.isEnabled {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        if element.exists, element.isEnabled {
            return true
        }
        fail("Element never became enabled", file: file, line: line)
        return false
    }

    func assertButtonExists(
        _ identifier: String,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = button(identifier)
        guard element.waitForExistence(timeout: timeout) else {
            fail("Button '\(identifier)' not found", file: file, line: line)
            return
        }
    }

    func assertExists(
        _ identifier: String,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier]
        guard element.waitForExistence(timeout: timeout) else {
            fail(missingElementMessage("Element '\(identifier)' not found"), file: file, line: line)
            return
        }
    }

    func assertExists(
        _ element: XCUIElement,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard element.waitForExistence(timeout: timeout) else {
            fail(missingElementMessage("Element not found"), file: file, line: line)
            return
        }
    }

    private func missingElementMessage(_ message: String) -> String {
        guard let app else { return message }
        var entries: [String] = []
        var seen: Set<String> = []
        for element in app.descendants(matching: .any).allElementsBoundByIndex {
            let identifier = element.identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !identifier.isEmpty else { continue }
            let normalizedIdentifier = identifier.replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            let entry = "\(String(describing: element.elementType))[\(normalizedIdentifier)]"
            guard seen.insert(entry).inserted else { continue }
            entries.append(entry)
            if entries.count == 30 {
                break
            }
        }
        if entries.isEmpty {
            return "\(message)\nAccessibility snapshot:\nAX: (no identified elements)"
        }
        var lines: [String] = []
        for start in stride(from: 0, to: entries.count, by: 4) {
            let end = min(start + 4, entries.count)
            lines.append("AX: " + entries[start ..< end].joined(separator: "; "))
        }
        var snapshot = lines.joined(separator: "\n")
        if snapshot.count > 2400 {
            snapshot = String(snapshot.prefix(2399)) + "…"
        }
        return "\(message)\nAccessibility snapshot:\n\(snapshot)"
    }

    func assertDoesNotExist(
        _ identifier: String,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier]
        if element.exists {
            guard element.waitForNonExistence(timeout: timeout) else {
                fail("Element '\(identifier)' still present", file: file, line: line)
                return
            }
        }
    }

    func assertExistsAfterScroll(
        _ identifier: String,
        maxAttempts: Int = 8,
        requireHittable: Bool = false,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier]
        scrollUntilVisible(
            element,
            swipingUp: true,
            maxAttempts: maxAttempts,
            requireHittable: requireHittable,
            file: file,
            line: line
        )
        if !element.exists {
            // One reverse pass in case the list started mid-scroll.
            scrollUntilVisible(
                element,
                swipingUp: false,
                maxAttempts: max(3, maxAttempts / 2),
                requireHittable: requireHittable,
                file: file,
                line: line
            )
        }
        guard element.exists else {
            fail("Element '\(identifier)' not found after scroll", file: file, line: line)
            return
        }
        if requireHittable, !element.isHittable {
            fail("Element '\(identifier)' not hittable after scroll", file: file, line: line)
        }
    }

    func goBack() {
        let navBackButton = app.navigationBars.buttons.firstMatch
        guard navBackButton.waitForExistence(timeout: 2) else { return }
        if navBackButton.isHittable {
            navBackButton.tap()
        } else {
            navBackButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Scrolls until `element` exists (and optionally is hittable). Prefer this over
    /// ad-hoc `swipeUp` loops when a control is in the hierarchy but covered/off-screen.
    func scrollUntilVisible(
        _ element: XCUIElement,
        swipingUp: Bool,
        maxAttempts: Int = 6,
        requireHittable: Bool = false,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        app.scrollUntilVisible(
            element,
            swipingUp: swipingUp,
            maxAttempts: maxAttempts,
            requireHittable: requireHittable
        )
    }

    func dismissSheet() {
        let closeButton = app.navigationBars.buttons["Close"]
        if closeButton.waitForExistence(timeout: 2), closeButton.isHittable {
            closeButton.tap()
            _ = closeButton.waitForNonExistence(timeout: 3)
        } else {
            sheetDismissDragStart.press(forDuration: 0.1, thenDragTo: sheetDismissDragEnd)
            _ = closeButton.waitForNonExistence(timeout: 3)
        }
    }

    var sheetDismissDragStart: XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
    }

    var sheetDismissDragEnd: XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
    }

    var edgeBackSwipeStart: XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.45))
    }

    var edgeBackSwipeEnd: XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.45))
    }

    func clearAndEnterText(_ element: XCUIElement, _ text: String) {
        replaceText(in: element, with: text)
    }

    func replaceText(in element: XCUIElement, with text: String) {
        element.tap()
        let clearButton = element.buttons["Clear text"]
        if clearButton.waitForExistence(timeout: 1) {
            clearButton.tap()
        } else if let stringValue = element.value as? String, !stringValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
            element.typeText(deleteString)
        }
        if !text.isEmpty {
            element.typeText(text)
        }
    }

    func fail(_ message: String, file: StaticString = #file, line: UInt = #line) {
        attachScreenshotOnFailure()
        XCTFail(message, file: file, line: line)
    }

    private func attachScreenshotOnFailure() {
        guard let app else { return }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension XCUIApplication {
    /// Shared scroll hunt used by page objects and `TrinketUITestCase` helpers.
    func scrollUntilVisible(
        _ element: XCUIElement,
        swipingUp: Bool,
        maxAttempts: Int = 8,
        requireHittable: Bool = false
    ) {
        for _ in 0 ..< maxAttempts {
            if element.exists, !requireHittable || element.isHittable {
                return
            }
            if swipingUp {
                dragScroll(fromY: 0.90, toY: 0.35)
            } else {
                dragScroll(fromY: 0.35, toY: 0.90)
            }
            _ = element.waitForExistence(timeout: 0.25)
        }
    }

    private func scrollContainer() -> XCUIElement {
        // Prefer the frontmost tab surface. Inactive tabs often remain in the AX
        // hierarchy; always choosing Play made Homestead scrolls miss list content.
        let candidates = [
            AccessibilityID.Screen.collection,
            AccessibilityID.Screen.homestead,
            AccessibilityID.Screen.play,
            AccessibilityID.Screen.options,
        ]
        for identifier in candidates {
            let screen = descendants(matching: .any)[identifier]
            if screen.exists, screen.isHittable {
                return screen
            }
        }
        for identifier in candidates {
            let screen = descendants(matching: .any)[identifier]
            if screen.exists, screen.frame.width > 1, screen.frame.height > 1 {
                return screen
            }
        }
        return self
    }

    private func dragScroll(fromY: CGFloat, toY: CGFloat) {
        let container = scrollContainer()
        let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
        let end = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
}
