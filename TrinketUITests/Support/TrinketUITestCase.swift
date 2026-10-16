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

/// Snapshot objects stay on the main actor; only their value projections cross back.
func trinketOnMainActor<Value: Sendable>(_ body: @MainActor () throws -> Value) rethrows -> Value {
    if Thread.isMainThread {
        return try MainActor.assumeIsolated { try body() }
    }
    return try DispatchQueue.main.sync {
        try MainActor.assumeIsolated { try body() }
    }
}

private func trinketInteger(in snapshot: any XCUIElementSnapshot) throws -> Int {
    let text = (snapshot.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? snapshot.label
    let digits = text.replacingOccurrences(of: ",", with: "").split(whereSeparator: { !$0.isNumber }).first
    return try XCTUnwrap(digits.flatMap { Int($0) }, "Missing numeric amount: \(text)")
}

enum TestLaunchArg {
    static let resetState = "-reset-state"
    static let seedTestProgress = "-seed-test-progress"
    static let skipStarterSelection = "-skip-starter-selection"
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
    private var hasCapturedFailureScreenshot = false

    var play: PlayScreen {
        PlayScreen(app: app)
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

    var battle: BattleScreen {
        BattleScreen(app: app)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        hasCapturedFailureScreenshot = false
        continueAfterFailure = false
    }

    override func record(_ issue: XCTIssue) {
        var recordedIssue = issue
        if issue.isFailure, !hasCapturedFailureScreenshot, let app {
            hasCapturedFailureScreenshot = true
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "Failure Screenshot"
            attachment.lifetime = .keepAlways
            recordedIssue.attachments.append(attachment)
            let description = trinketOnMainActor {
                app.state == .runningForeground
                    ? app.debugDescription
                    : "Application state: \(app.state.rawValue); no foreground application hierarchy."
            }
            let bounded = description.count > 24000
                ? String(description.prefix(12000)) + "\n… hierarchy middle omitted …\n" + String(description.suffix(12000))
                : description
            let hierarchy = XCTAttachment(string: bounded)
            hierarchy.name = "Failure Accessibility Hierarchy"
            hierarchy.lifetime = .keepAlways
            recordedIssue.attachments.append(hierarchy)
        }
        super.record(recordedIssue)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        try super.tearDownWithError()
    }

    func launchApp(arguments: [String] = [], waitForPreparation: Bool = true) {
        app = XCUIApplication()
        var launchArgs = arguments
        launchArgs.append(contentsOf: ["-store-name", storeName])
        app.launchArguments = launchArgs
        var launchEnvironment = app.launchEnvironment
        if let quick = ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"], !quick.isEmpty {
            launchEnvironment["TRINKET_PERFORMANCE_QUICK"] = quick
        }
        app.launchEnvironment = launchEnvironment
        app.launch()
        if waitForPreparation {
            waitForLaunchPreparation()
        }
    }

    func backgroundAndActivate() {
        XCUIApplication(bundleIdentifier: "com.apple.springboard").activate()
        waitUntil("App must enter the background before reactivation") {
            let state = self.app.state
            return state == .runningBackground || state == .runningBackgroundSuspended
        }
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: Self.defaultTimeout))
    }

    func dismissEarnedTalentChoicesIfPresented() {
        let choices = any(AccessibilityID.TalentChoice.screen)
        let board = any(AccessibilityID.Play.contractsBoard)
        waitUntil("Contract must return to its board or earned talent choice") {
            choices.exists || (board.exists && self.app.buttons[AccessibilityID.Tab.play].isHittable)
        }
        if choices.exists {
            dismissSheet(AccessibilityID.TalentChoice.screen)
        }
    }

    func coverageReport() throws -> [String: Any] {
        let probe = any(AccessibilityID.Debug.coverageDiagnostics)
        // Hierarchy snapshots truncate long values; the direct attribute retains the JSON.
        let encoded = try trinketOnMainActor { try XCTUnwrap(probe.value as? String) }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [String: Any])
    }

    func auditProductAccessibility() throws {
        let originalContinueAfterFailure = continueAfterFailure
        continueAfterFailure = true
        defer { continueAfterFailure = originalContinueAfterFailure }
        let application = try XCTUnwrap(app)
        try trinketOnMainActor {
            // Keep every iOS audit, but give each its own native deadline on older runtimes.
            let types: [XCUIAccessibilityAuditType] = [
                .contrast, .elementDetection, .hitRegion, .sufficientElementDescription,
                .dynamicType, .textClipped, .trait,
            ]
            for type in types {
                @MainActor func audit() throws {
                    try application.performAccessibilityAudit(for: type) { issue in
                        // Exclude only the opt-in Debug observation label, never product controls.
                        if issue.element?.identifier == AccessibilityID.Debug.coverageDiagnostics {
                            return true
                        }
                        let detail = "\(issue.compactDescription)\n\(issue.detailedDescription)\n"
                            + String((issue.element?.debugDescription ?? "No element").prefix(3000))
                        let attachment = XCTAttachment(string: detail)
                        let activityName = "Native audit \(issue.auditType.rawValue)"
                        attachment.name = activityName
                        attachment.lifetime = .keepAlways
                        XCTContext.runActivity(named: activityName) { activity in
                            activity.add(attachment)
                        }
                        return false
                    }
                }
                do {
                    try audit()
                } catch let error as NSError where error.domain == "com.apple.xcode.xctest.accessibilityAudit" && error.code == -56 {
                    // Retry one native audit timeout; violations and a second timeout still fail.
                    try audit()
                }
            }
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
        try trinketOnMainActor { try trinketInteger(in: element.snapshot()) }
    }

    func integers(in container: XCUIElement, identifiers: Set<String>) throws -> [String: Int] {
        try trinketOnMainActor {
            // Read one subtree so related amounts come from the same UI state.
            var pending = try [container.snapshot()]
            var amounts: [String: Int] = [:]
            while let snapshot = pending.popLast() {
                pending.append(contentsOf: snapshot.children)
                if identifiers.contains(snapshot.identifier) {
                    amounts[snapshot.identifier] = try trinketInteger(in: snapshot)
                }
            }
            return amounts
        }
    }

    func waitForLaunchPreparation() {
        let warmup = app.descendants(matching: .any)
            .matching(identifier: AccessibilityID.Screen.launchWarmup)
            .firstMatch
        XCTAssertTrue(
            warmup.waitForNonExistence(timeout: Self.launchWarmupTimeout),
            "Launch artwork preparation did not finish",
        )
        XCTAssertTrue(
            app.buttons.firstMatch.trinketWaitForExistence(timeout: Self.launchWarmupTimeout),
            "Launch must expose an interactive surface after artwork preparation",
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
        button(identifier).trinketTapWhenReady(timeout: timeout, file: file, line: line)
    }

    func tapWhenReady(_ element: XCUIElement, file: StaticString = #file, line: UInt = #line) {
        element.trinketTapWhenReady(file: file, line: line)
    }

    func assertExists(
        _ identifier: String,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        assertExists(any(identifier), timeout: timeout, message: "Element '\(identifier)' not found", file: file, line: line)
    }

    func assertExists(
        _ element: XCUIElement,
        timeout: TimeInterval = defaultTimeout,
        message: String = "Element not found",
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        guard element.trinketWaitForExistence(timeout: timeout) else {
            fail(missingElementMessage(message), file: file, line: line)
            return
        }
    }

    private func missingElementMessage(_ message: String) -> String {
        guard let app else { return message }
        return trinketOnMainActor {
            guard let snapshot = try? app.snapshot() else { return message }
            var entries: [String] = []
            var seen: Set<String> = []
            var pending = Array(snapshot.children.reversed())
            while let element = pending.popLast() {
                pending.append(contentsOf: element.children.reversed())
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
            let description = entries.isEmpty ? "AX: (no identified elements)" : entries.map { "AX: " + $0 }.joined(separator: "\n")
            let bounded = description.count > 2400 ? String(description.prefix(2399)) + "…" : description
            return "\(message)\nAccessibility snapshot:\n\(bounded)"
        }
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
        let visible = scrollUntilVisible(
            element,
            swipingUp: true,
            maxAttempts: maxAttempts,
            requireHittable: requireHittable,
        ) || scrollUntilVisible(
            element,
            swipingUp: false,
            maxAttempts: max(3, maxAttempts / 2),
            requireHittable: requireHittable,
        )
        XCTAssertTrue(
            visible,
            "Element '\(identifier)' not visible after scroll (hittable required: \(requireHittable))",
            file: file,
            line: line,
        )
    }

    @discardableResult
    func scrollUntilVisible(
        _ element: XCUIElement,
        swipingUp: Bool,
        maxAttempts: Int = 6,
        requireHittable: Bool = false,
    ) -> Bool {
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
        XCTFail(message, file: file, line: line)
    }

    /// Success-path screenshots bloat result bundles; capture them only with
    /// `TRINKET_UI_SUCCESS_SCREENSHOTS=1`. Failure screenshots are always retained.
    func attachSuccessScreenshot(named name: String) {
        guard ProcessInfo.processInfo.environment["TRINKET_UI_SUCCESS_SCREENSHOTS"] == "1", app != nil else { return }
        retainScreenshot(named: name)
    }
}

extension XCUIElement {
    func trinketTapWhenReady(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        func isReady(_ element: XCUIElement) -> Bool {
            trinketOnMainActor {
                guard let snapshot = try? element.snapshot(), snapshot.isEnabled else { return false }
                let bounds = snapshot.frame
                guard !bounds.isEmpty,
                      bounds.minX.isFinite, bounds.minY.isFinite,
                      bounds.maxX.isFinite, bounds.maxY.isFinite
                else { return false }
                return element.isHittable
            }
        }
        guard trinketWaitUntil(timeout: timeout, condition: { isReady(self) }) else {
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
        let bounds = frame
        if bounds.isEmpty || !bounds.minX.isFinite || !bounds.minY.isFinite
            || !bounds.maxX.isFinite || !bounds.maxY.isFinite || !isHittable {
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
    @discardableResult
    func scrollUntilVisible(
        _ element: XCUIElement,
        swipingUp: Bool,
        maxAttempts: Int = 8,
        requireHittable: Bool = false,
    ) -> Bool {
        if element.exists, !requireHittable || element.isHittable {
            return true
        }
        let container = scrollContainer(containing: element)
        let visibleBounds = scrollGestureBounds(in: container)
        guard !visibleBounds.isNull, !visibleBounds.isEmpty,
              visibleBounds.minX.isFinite, visibleBounds.minY.isFinite,
              visibleBounds.maxX.isFinite, visibleBounds.maxY.isFinite
        else { return false }
        for _ in 0 ..< maxAttempts {
            container.dragScroll(fromY: swipingUp ? 0.90 : 0.35, toY: swipingUp ? 0.35 : 0.90, within: visibleBounds)
            if trinketWaitForExistenceMainActorSafe(element, timeout: 0.35), !requireHittable || element.isHittable {
                return true
            }
        }
        return false
    }

    private func scrollContainer(containing element: XCUIElement) -> XCUIElement {
        let identifier = trinketOnMainActor { element.exists ? element.identifier : "" }
        if !identifier.isEmpty {
            // A visible nested carousel cannot scroll a sibling action into view.
            for query in [scrollViews, collectionViews, tables] {
                if let owner = query.containing(.any, identifier: identifier).allElementsBoundByIndex.last(where: { $0.isHittable }) {
                    return owner
                }
            }
        }
        return scrollViews.allElementsBoundByIndex.last { $0.isHittable }
            ?? collectionViews.allElementsBoundByIndex.last { $0.isHittable }
            ?? tables.allElementsBoundByIndex.last { $0.isHittable }
            ?? self
    }

    private func scrollGestureBounds(in container: XCUIElement) -> CGRect {
        trinketOnMainActor {
            var bounds = container.frame.intersection(frame)
            let nativeBar = tabBars.firstMatch
            let barTop: CGFloat?
            if nativeBar.exists, nativeBar.isHittable {
                barTop = nativeBar.frame.minY
            } else {
                // Some runtimes expose the floating tab bar as toolbar buttons.
                let tabs = ["Play", "Collection", "Homestead", "Options"].compactMap { title -> CGFloat? in
                    let button = buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", title, "BackButton")).firstMatch
                    guard button.exists, button.isHittable, button.frame.midY > frame.midY else { return nil }
                    return button.frame.minY
                }
                barTop = tabs.count == 4 ? tabs.min() : nil
            }
            if let barTop, barTop > bounds.minY, barTop < bounds.maxY {
                bounds.size.height = barTop - bounds.minY
            }
            // safeAreaInset leaves the scroll view's frame behind its pinned action.
            // Start gestures in the exposed content rather than on the purchase button.
            for identifier in [AccessibilityID.FullGame.purchase, AccessibilityID.FullGame.retry] {
                let action = buttons[identifier].firstMatch
                if action.exists, action.isHittable,
                   action.frame.minY > bounds.minY, action.frame.minY < bounds.maxY {
                    bounds.size.height = action.frame.minY - bounds.minY
                }
            }
            return bounds
        }
    }
}

extension XCUIElement {
    func dragScroll(fromY: CGFloat, toY: CGFloat, within bounds: CGRect) {
        trinketOnMainActor {
            let origin = coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: bounds.midX - frame.minX, dy: bounds.minY + bounds.height * fromY - frame.minY))
            let end = origin.withOffset(CGVector(dx: bounds.midX - frame.minX, dy: bounds.minY + bounds.height * toY - frame.minY))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }
}
