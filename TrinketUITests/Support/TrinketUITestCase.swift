import TrinketFeatureSupport
import XCTest

func trinketWaitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
    if condition() {
        return true
    }
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
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

    static func allForBattle() -> [String] {
        allForScreen("battle")
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
    private var failurePhase = "setup"
    private var phaseStartedAt = Date.now

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
        failurePhase = "setup"
        phaseStartedAt = .now
        continueAfterFailure = false
    }

    override func record(_ issue: XCTIssue) {
        var recordedIssue = issue
        if issue.isFailure, !hasCapturedFailureScreenshot, let app {
            hasCapturedFailureScreenshot = true
            let snapshotTimeout = issue.type == .system && issue.compactDescription.contains(
                "Failed to get matching snapshots: Timed out while evaluating UI query.",
            )
            if snapshotTimeout, failurePhase == "launch-preparation" {
                recordedIssue.compactDescription = "[Trinket launch snapshot timeout] \(issue.compactDescription)"
            }
            let context = XCTAttachment(
                string:
                "Phase: \(failurePhase)\nElapsed: \(Date.now.timeIntervalSince(phaseStartedAt))s\n"
                    + "Application state: \(app.state.rawValue)\n"
                    + "Runtime: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
                    + "Launch arguments: \(app.launchArguments.joined(separator: " "))",
            )
            context.name = "Failure Context"
            context.lifetime = .keepAlways
            recordedIssue.attachments.append(context)
            let imageData = trinketOnMainActor { XCUIScreen.main.screenshot().pngRepresentation }
            let attachment = imageData.isEmpty
                ? XCTAttachment(string: "XCTest returned an empty screenshot; see host simulator diagnostics.")
                : XCTAttachment(data: imageData, uniformTypeIdentifier: "public.png")
            attachment.name = "Failure Screenshot"
            attachment.lifetime = .keepAlways
            recordedIssue.attachments.append(attachment)
            let description = trinketOnMainActor {
                app.state == .runningForeground && !snapshotTimeout
                    ? app.debugDescription
                    : "Application state: \(app.state.rawValue); hierarchy omitted after a snapshot timeout or background exit."
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
        failurePhase = "app-launch"
        phaseStartedAt = .now
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
        } else {
            failurePhase = "interaction"
            phaseStartedAt = .now
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
        let probe = app.staticTexts[AccessibilityID.Debug.coverageDiagnostics]
        // Hierarchy snapshots truncate long values; the direct attribute retains the JSON.
        let encoded = try trinketOnMainActor { try XCTUnwrap(probe.value as? String) }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [String: Any])
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
        failurePhase = "launch-preparation"
        phaseStartedAt = .now
        defer {
            failurePhase = "interaction"
            phaseStartedAt = .now
        }
        let warmup = app.otherElements
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
        XCTAssertTrue(element.trinketWaitForExistence(timeout: timeout), message, file: file, line: line)
    }

    func assertDoesNotExist(
        _ identifier: String,
        timeout: TimeInterval = defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = any(identifier)
        if element.exists {
            XCTAssertTrue(element.waitForNonExistence(timeout: timeout), "Element '\(identifier)' still present", file: file, line: line)
        }
    }

    func reveal(
        _ element: XCUIElement,
        maxAttempts: Int = 8,
        requireHittable: Bool = true,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let visible = app.scrollUntilVisible(
            element,
            swipingUp: true,
            maxAttempts: maxAttempts,
            requireHittable: requireHittable,
        ) || app.scrollUntilVisible(
            element,
            swipingUp: false,
            maxAttempts: max(3, maxAttempts / 2),
            requireHittable: requireHittable,
        )
        XCTAssertTrue(
            visible,
            "Element '\(element.identifier)' not visible after scroll (hittable required: \(requireHittable))",
            file: file,
            line: line,
        )
    }

    func tapButtonAfterScroll(_ identifier: String, file: StaticString = #file, line: UInt = #line) {
        let control = button(identifier)
        reveal(control, file: file, line: line)
        control.trinketTapWhenReady(file: file, line: line)
    }

    func dismissSheet(_ identifier: String) {
        assertExists(identifier)
        let close = app.buttons["Close"]
        if close.exists, close.isHittable {
            tapWhenReady(close)
        } else {
            let grabber = app.buttons["Sheet Grabber"].firstMatch
            let bar = app.navigationBars.allElementsBoundByIndex.last { $0.isHittable }
            let start = (grabber.exists && grabber.isHittable
                ? grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)) : nil)
                ?? bar?.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
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
        trinketOnMainActor { exists || waitForExistence(timeout: timeout) }
    }
}

extension XCUIApplication {
    @discardableResult
    func scrollUntilVisible(
        _ element: XCUIElement,
        swipingUp: Bool,
        maxAttempts: Int = 6,
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
            if element.trinketWaitForExistence(timeout: 0.35), !requireHittable || element.isHittable {
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
                    // Lazy lists recycle the target row while scrolling. Keep the
                    // container query independent of that row once its owner is found.
                    let ownerID = owner.identifier
                    return ownerID.isEmpty ? owner : query.matching(identifier: ownerID).firstMatch
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
