import XCTest

enum TestLaunchArg {
    static func tab(_ tab: String) -> String {
        "-selectedTab \(tab)"
    }

    static let resetState = "-reset-state"
    static let seedTestProgress = "-seed-test-progress"
    static let disableCloudSync = "-disable-cloud-sync"
    static let testLaunchArgs = [
        resetState,
        seedTestProgress,
        disableCloudSync,
        "-disable-audio",
        "-persist-save-immediately",
        "-battle-tick-interval",
        "1.0"
    ]
    static func screen(_ screen: String) -> [String] {
        ["-launch-screen", screen]
    }

    static func completedStages(_ stageIDs: [String]) -> [String] {
        ["-completed-stages", stageIDs.joined(separator: ",")]
    }

    static func mapScrollTarget(_ targetID: String) -> [String] {
        ["-map-scroll-target", targetID]
    }

    static func mysteryRecruit(eventID: String) -> [String] {
        ["-mystery-recruit-event", eventID]
    }

    static func allForTab(_ tab: String, reset: Bool = true) -> [String] {
        var args = reset ? testLaunchArgs : []
        args.append(contentsOf: ["-selectedTab", tab])
        return args
    }

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

    static func allForBattlePerformance(
        _ scenario: String,
        reset: Bool = true
    ) -> [String] {
        var args = allForBattle(reset: reset)
        // Performance runs exercise the real SFX playback path. Cloud sync remains off
        // because it is unrelated external work and would reduce repeatability.
        args.removeAll { $0 == "-disable-audio" }
        args += [enableFrameMetrics, "-battle-performance-scenario", scenario]
        return args
    }

    static func allForBattleVictory(reset: Bool = true) -> [String] {
        allForScreen("battle-victory", reset: reset)
    }

    /// Play-map mid-battle exhaustive entry. Slower ticks keep combatant chrome
    /// reachable while XCTest opens the campaign and asserts turn-based UI.
    static func allForMidBattle() -> [String] {
        replacingBattleTickInterval("3.0", in: testLaunchArgs)
    }

    static func allForShop(reset: Bool = true) -> [String] {
        allForScreen("shop", reset: reset)
    }

    static func allForMystery(reset: Bool = true) -> [String] {
        allForScreen("mystery", reset: reset)
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

    func assertCombatantDetailSections(
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        combatantDetail.assertSections(timeout: timeout, file: file, line: line)
    }

    func assertExists(
        _ identifier: String,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier]
        guard element.waitForExistence(timeout: timeout) else {
            fail("Element '\(identifier)' not found", file: file, line: line)
            return
        }
    }

    func assertItemCardExists(
        _ itemName: String,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let card = app.buttons.matching(identifier: "\(itemName) item card").firstMatch
        guard card.waitForExistence(timeout: timeout) else {
            fail("Item card '\(itemName)' not found", file: file, line: line)
            return
        }
    }

    func assertItemCardExistsAfterScroll(
        _ itemName: String,
        maxAttempts: Int = 8,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let card = app.buttons.matching(identifier: "\(itemName) item card").firstMatch
        scrollUntilVisible(card, swipingUp: true, maxAttempts: maxAttempts, file: file, line: line)
        guard card.exists else {
            fail("Item card '\(itemName)' not found", file: file, line: line)
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
            fail("Element not found", file: file, line: line)
            return
        }
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
        maxAttempts: Int = 6,
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
        guard element.exists else {
            fail("Element '\(identifier)' not found after scroll", file: file, line: line)
            return
        }
        if requireHittable, !element.isHittable {
            fail("Element '\(identifier)' not hittable after scroll", file: file, line: line)
        }
    }

    func goBack() {
        let navBackButton = app.navigationBars.buttons.element(boundBy: 0)
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
        for _ in 0 ..< maxAttempts {
            if element.exists, !requireHittable || element.isHittable {
                return
            }
            if swipingUp {
                dragScroll(fromY: 0.90, toY: 0.35)
            } else {
                dragScroll(fromY: 0.35, toY: 0.90)
            }
            _ = element.waitForExistence(timeout: 0.15)
        }
    }

    private func scrollContainer() -> XCUIElement {
        let playScreen = app.descendants(matching: .any)[AccessibilityID.Screen.play]
        if playScreen.exists {
            return playScreen
        }
        return app
    }

    private func dragScroll(fromY: CGFloat, toY: CGFloat) {
        let container = scrollContainer()
        let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
        let end = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func dismissSheet() {
        let closeButton = app.navigationBars.buttons["Close"]
        if closeButton.waitForExistence(timeout: 2), closeButton.isHittable {
            closeButton.tap()
            _ = closeButton.waitForNonExistence(timeout: 3)
        } else {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            start.press(forDuration: 0.1, thenDragTo: end)
            _ = closeButton.waitForNonExistence(timeout: 3)
        }
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
