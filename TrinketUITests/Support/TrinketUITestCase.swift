import TrinketFeatureSupport
import XCTest

func trinketWaitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
    if condition() {
        return true
    }
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
}

private func trinketWaitForExistenceMainActorSafe(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
    if Thread.isMainThread {
        return MainActor.assumeIsolated { element.exists || element.waitForExistence(timeout: timeout) }
    }
    return DispatchQueue.main.sync {
        MainActor.assumeIsolated { element.exists || element.waitForExistence(timeout: timeout) }
    }
}

enum TestLaunchArg {
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
        "-battle-tick-interval",
        "1.0",
    ]
    static func screen(_ screen: String) -> [String] {
        ["-launch-screen", screen]
    }

    static func allUnseeded() -> [String] {
        [
            resetState,
            disableCloudSync,
            skipStarterSelection,
            "-disable-audio",
        ]
    }

    static func completedStages(_ stageIDs: [String]) -> [String] {
        ["-completed-stages", stageIDs.joined(separator: ",")]
    }

    static func mysteryRecruit(eventID: String) -> [String] {
        ["-mystery-recruit-event", eventID]
    }

    static func allForTab(_ tab: String) -> [String] {
        testLaunchArgs + ["-selectedTab", tab]
    }

    static func allForScreen(_ screen: String) -> [String] {
        testLaunchArgs + self.screen(screen)
    }

    static func allForBattle(fastTicks: Bool = false) -> [String] {
        let args = allForScreen("battle")
        if fastTicks {
            return replacingBattleTickInterval("0.01", in: args)
        }
        return args
    }

    static func productionTiming(tab: String = "play", audio: Bool = false) -> [String] {
        var args = allForTab(tab)
        if let index = args.firstIndex(of: "-battle-tick-interval") {
            args.removeSubrange(index ... index + 1)
        }
        if audio {
            args.removeAll { $0 == "-disable-audio" }
        }
        return args
    }

    static let rewardCheckpoint = "-hold-reward-collection"

    static let enableFrameMetrics = "-enable-frame-metrics"

    static func allForAppPerformance(tab: String = "play") -> [String] {
        performanceArguments(from: allForTab(tab))
    }

    static func allForBattlePerformance(
        _ scenario: String,
    ) -> [String] {
        var args = performanceArguments(from: allForBattle())
        args += ["-battle-performance-scenario", scenario]
        if ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1" {
            args.append("-battle-performance-quick")
        }
        return args
    }

    static func performanceArguments(from arguments: [String]) -> [String] {
        var result = arguments
        result.removeAll { $0 == "-disable-audio" || $0 == enableFrameMetrics }
        result.append(enableFrameMetrics)
        return result
    }

    static func allForMidBattle() -> [String] {
        replacingBattleTickInterval("60", in: testLaunchArgs)
    }

    static func allForShop() -> [String] {
        allForScreen("shop")
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
    static let defaultTimeout: TimeInterval = 12
    static let deepLinkTimeout: TimeInterval = 15
    static let launchWarmupTimeout: TimeInterval = 60

    // swiftlint:disable:next implicitly_unwrapped_optional - XCTest installs the app before each test
    private(set) var app: XCUIApplication!
    private let storeName = UUID().uuidString

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

    func launchApp(arguments: [String] = [], waitForPreparation: Bool = true) {
        app = XCUIApplication()
        var launchArgs = arguments
        launchArgs.append(contentsOf: ["-store-name", storeName])
        app.launchArguments = launchArgs
        var launchEnvironment = app.launchEnvironment
        for key in ["TRINKET_PERFORMANCE_QUICK"] {
            if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
                launchEnvironment[key] = value
            }
        }
        app.launchEnvironment = launchEnvironment
        app.launch()
        if waitForPreparation {
            waitForLaunchPreparation()
        }
    }

    func backgroundAndActivate() {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: Self.defaultTimeout))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: Self.defaultTimeout))
    }

    func dismissEarnedTalentChoicesIfPresented() {
        let choices = any(AccessibilityID.TalentChoice.screen)
        if choices.trinketWaitForExistence(timeout: 1) {
            dismissSheet(AccessibilityID.TalentChoice.screen)
        }
    }

    func coverageReport() throws -> [String: Any] {
        let probe = any(AccessibilityID.Debug.coverageDiagnostics)
        assertExists(probe)
        let encoded = try XCTUnwrap(probe.value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [String: Any])
    }

    func waitForAudioProgress(after plays: Int) {
        waitUntil("Real backend must schedule another sound") {
            do {
                return try (self.coverageReport()["sfxPlays"] as? Int ?? 0) > plays
            } catch {
                return false
            }
        }
    }

    func auditProductAccessibility() throws {
        try app.performAccessibilityAudit { issue in
            // Exclude only the opt-in Debug observation label, never product controls.
            issue.element?.identifier == AccessibilityID.Debug.coverageDiagnostics
        }
    }

    func retainScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func relaunchApp(arguments: [String] = []) {
        app.terminate()
        launchApp(arguments: [TestLaunchArg.disableCloudSync, "-disable-audio"] + arguments)
    }

    func waitUntil(_ message: String, timeout: TimeInterval = defaultTimeout, condition: @escaping () -> Bool) {
        XCTAssertTrue(trinketWaitUntil(timeout: timeout, condition: condition), message)
    }

    func integer(in element: XCUIElement) throws -> Int {
        let text = (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
        let digits = text.replacingOccurrences(of: ",", with: "").split(whereSeparator: { !$0.isNumber }).first
        return try XCTUnwrap(digits.flatMap { Int($0) }, "Missing numeric amount: \(text)\n\(element.debugDescription)")
    }

    func waitForLaunchPreparation() {
        let warmup = app.descendants(matching: .any)
            .matching(identifier: AccessibilityID.Screen.launchWarmup)
            .firstMatch
        XCTAssertTrue(
            warmup.waitForNonExistence(timeout: Self.launchWarmupTimeout),
            "Launch artwork preparation did not finish",
        )
    }

    func button(_ identifier: String) -> XCUIElement {
        app.buttons[identifier]
    }

    func any(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    func tapButton(
        _ identifier: String,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = button(identifier)
        guard waitForExistence(element, timeout: timeout) else {
            fail("Button '\(identifier)' not found", file: file, line: line)
            return
        }
        tapWhenReady(element, file: file, line: line)
    }

    @discardableResult
    func waitForExistence(
        _ element: XCUIElement,
        timeout: TimeInterval,
        file _: StaticString = #file,
        line _: UInt = #line,
    ) -> Bool {
        trinketWaitForExistenceMainActorSafe(element, timeout: timeout)
    }

    func tapWhenReady(_ element: XCUIElement, file: StaticString = #file, line: UInt = #line) {
        element.trinketTapWhenReady(file: file, line: line)
    }

    func assertButtonExists(
        _ identifier: String,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = button(identifier)
        guard waitForExistence(element, timeout: timeout) else {
            fail("Button '\(identifier)' not found", file: file, line: line)
            return
        }
    }

    func assertExists(
        _ identifier: String,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = app.descendants(matching: .any)[identifier]
        guard waitForExistence(element, timeout: timeout) else {
            fail(missingElementMessage("Element '\(identifier)' not found"), file: file, line: line)
            return
        }
    }

    func assertExists(
        _ element: XCUIElement,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        guard waitForExistence(element, timeout: timeout) else {
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
                options: .regularExpression,
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
        line: UInt = #line,
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
        line: UInt = #line,
    ) {
        let element = app.descendants(matching: .any)[identifier]
        scrollUntilVisible(
            element,
            swipingUp: true,
            maxAttempts: maxAttempts,
            requireHittable: requireHittable,
            file: file,
            line: line,
        )
        if !element.exists || (requireHittable && !element.isHittable) {
            scrollUntilVisible(
                element,
                swipingUp: false,
                maxAttempts: max(3, maxAttempts / 2),
                requireHittable: requireHittable,
                file: file,
                line: line,
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
        tapWhenReady(app.navigationBars.buttons["BackButton"])
    }

    func scrollUntilVisible(
        _ element: XCUIElement,
        swipingUp: Bool,
        maxAttempts: Int = 6,
        requireHittable: Bool = false,
        file _: StaticString = #file,
        line _: UInt = #line,
    ) {
        app.scrollUntilVisible(
            element,
            swipingUp: swipingUp,
            maxAttempts: maxAttempts,
            requireHittable: requireHittable,
        )
    }

    func dismissSheet(_ identifier: String) {
        assertExists(identifier)
        let close = app.buttons["Close"]
        if close.exists, close.isHittable {
            tapWhenReady(close)
        } else {
            let bar = app.navigationBars.allElementsBoundByIndex.last { $0.isHittable }
            let start = bar?.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
                ?? app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.09))
            start.press(forDuration: 0.1, thenDragTo: sheetDismissDragEnd)
        }
        assertDoesNotExist(identifier)
    }

    var sheetDismissDragStart: XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
    }

    var sheetDismissDragEnd: XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
    }

    func replaceText(in element: XCUIElement, with text: String) {
        tapWhenReady(element)
        let clearButton = element.buttons["Clear text"]
        if clearButton.exists {
            clearButton.tap()
        } else if let stringValue = element.value as? String,
                  !stringValue.isEmpty, stringValue != element.placeholderValue {
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

    /// Success-path screenshots bloat result bundles; capture them only with
    /// `TRINKET_UI_SUCCESS_SCREENSHOTS=1`. Failure screenshots via `fail()` are unaffected.
    func attachSuccessScreenshot(named name: String) {
        guard ProcessInfo.processInfo.environment["TRINKET_UI_SUCCESS_SCREENSHOTS"] == "1",
              let app else { return }
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = name
        preview.lifetime = .keepAlways
        add(preview)
    }

    private func attachScreenshotOnFailure() {
        guard let app else { return }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension XCUIElement {
    func trinketTapWhenReady(file: StaticString = #file, line: UInt = #line) {
        func isReady(_ element: XCUIElement) -> Bool {
            guard element.exists, element.isEnabled else { return false }
            let bounds = element.frame
            guard !bounds.isEmpty,
                  bounds.minX.isFinite, bounds.minY.isFinite,
                  bounds.maxX.isFinite, bounds.maxY.isFinite
            else { return false }
            return element.isHittable
        }
        guard trinketWaitUntil(timeout: TrinketUITestCase.defaultTimeout, condition: { isReady(self) }) else {
            XCTFail(
                "Control '\(identifier)' not ready: exists=\(exists), enabled=\(isEnabled), hittable=\(isHittable), frame=\(frame)",
                file: file,
                line: line,
            )
            return
        }
        // Animations can flip hittability between predicate fulfillment and
        // tap ("Activation point invalid"); re-validate once without growing
        // the happy-path budget, settling briefly only on a detected race.
        if !isReady(self) {
            guard trinketWaitUntil(timeout: 2, condition: { isReady(self) }) else {
                XCTFail(
                    "Control '\(identifier)' not stable: exists=\(exists), enabled=\(isEnabled), hittable=\(isHittable), frame=\(frame)",
                    file: file,
                    line: line,
                )
                return
            }
        }
        tap()
    }

    func trinketWaitForExistence(timeout: TimeInterval) -> Bool {
        trinketWaitForExistenceMainActorSafe(self, timeout: timeout)
    }
}

extension XCUIApplication {
    func scrollUntilVisible(
        _ element: XCUIElement,
        swipingUp: Bool,
        maxAttempts: Int = 8,
        requireHittable: Bool = false,
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
            let wait: TimeInterval = 0.35
            _ = trinketWaitForExistenceMainActorSafe(element, timeout: wait)
        }
    }

    private func scrollContainer() -> XCUIElement {
        scrollViews.allElementsBoundByIndex.last { $0.isHittable }
            ?? collectionViews.allElementsBoundByIndex.last { $0.isHittable }
            ?? tables.allElementsBoundByIndex.last { $0.isHittable }
            ?? self
    }

    private func dragScroll(fromY: CGFloat, toY: CGFloat) {
        let container = scrollContainer()
        let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
        let end = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
}
