import TrinketFeatureSupport
import XCTest

class PerformanceJourneyUITestCase: TrinketUITestCase {
    private var completedSteps: [Int: Set<String>] = [:]

    private var currentTestSelection: Set<String>? {
        guard let raw = ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_TEST_SCENARIOS"],
              let data = raw.data(using: .utf8),
              let selections = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return nil }
        let entry = selections.first { key, _ in
            let parts = key.split(separator: "/")
            return parts.count == 2 && name.contains("[\(parts[0]) ") && name.hasSuffix(" \(parts[1])]")
        }
        return entry.map { Set($0.value) }
    }

    var repetitionCount: Int {
        max(1, Int(ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_REPETITIONS"] ?? "1") ?? 1)
    }

    func selected(_ scenario: String) -> Bool {
        guard let selection = ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_SCENARIOS"] else { return true }
        return selection.split(separator: ",").contains(Substring(scenario))
    }

    @MainActor
    func measured(_ scenario: String, iteration: Int = 1, settle: TimeInterval = 1.5, action: () -> Void) {
        guard selected(scenario) else {
            if currentTestSelection.map({ !$0.isSubset(of: completedSteps[iteration] ?? []) }) ?? true {
                action()
            }
            return
        }
        prepareMeasurement()
        measurementControl.tap()
        waitForMeasurementState("measuring")
        action()
        finishMeasurement(scenario, iteration: iteration, settle: settle)
        completedSteps[iteration, default: []].insert(scenario)
    }

    var measurementControl: XCUICoordinate {
        let control = app.buttons[AccessibilityID.Debug.frameMetricsReset]
        XCTAssertTrue(control.trinketWaitForExistence(timeout: Self.defaultTimeout))
        return control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }

    func prepareMeasurement() {
        measurementControl.tap()
        waitForMeasurementState("ready")
    }

    func waitForMeasurementState(_ state: String) {
        let metrics = app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", state), object: metrics)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 4), .completed)
    }

    @MainActor
    func finishMeasurement(_ scenario: String, iteration: Int, settle: TimeInterval = 1.5, suite: String = "app") {
        RunLoop.current.run(until: Date().addingTimeInterval(settle))
        // A watchdog result is a failure, never a new capture or an accepted late action.
        let metrics = app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
        XCTAssertEqual(metrics.value as? String, "measuring", "Capture ended before interaction: \(scenario)")
        measurementControl.tap()
        PerformanceReportRecorder.capture(from: app, scenario: scenario, suite: suite, iteration: iteration, in: self)
    }

    func reveal(_ element: XCUIElement) {
        for _ in 0 ..< 8 {
            if element.exists, element.isHittable {
                return
            }
            if element.exists, element.frame.midY < app.frame.midY {
                app.swipeDown(velocity: .fast)
            } else {
                app.swipeUp(velocity: .fast)
            }
        }
        XCTAssertTrue(element.exists && element.isHittable, "Control could not be revealed")
    }

    override func dismissSheet() {
        let close = app.navigationBars.buttons["Close"]
        if close.exists, close.isHittable {
            close.tap()
        } else {
            // Drag native sheet chrome, not scrolled detail content.
            let bar = app.navigationBars.allElementsBoundByIndex.last { $0.isHittable }
            let start = bar?.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
                ?? app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.09))
            start.press(forDuration: 0.1, thenDragTo: sheetDismissDragEnd)
        }
    }

    var horizontalScrollView: XCUIElement {
        app.scrollViews.allElementsBoundByIndex.first {
            $0.frame.width > $0.frame.height && $0.frame.minY > 100 && $0.frame.maxY < app.frame.maxY - 90
        } ?? app.scrollViews["Missing horizontal scroll view"]
    }

    struct ScrollAnchor {
        let key: String
        let frame: CGRect
    }

    @MainActor
    private func anchors(in snapshot: any XCUIElementSnapshot, horizontal: Bool) -> [ScrollAnchor] {
        let viewport = snapshot.frame
        var pending = snapshot.children
        var result: [ScrollAnchor] = []
        while let child = pending.popLast() {
            pending.append(contentsOf: child.children)
            let frame = child.frame
            if child.identifier.isEmpty, child.label.isEmpty {
                continue
            }
            if !frame.isEmpty, frame.minX.isFinite, frame.minY.isFinite, frame.maxX.isFinite, frame.maxY.isFinite,
               horizontal ? frame.width < viewport.width * 0.9 : frame.height < viewport.height * 0.9,
               frame.intersects(viewport) {
                result.append(ScrollAnchor(key: "\(child.elementType.rawValue):\(child.identifier):\(child.label)", frame: frame))
            }
        }
        return result
    }

    @MainActor
    func captureScrollProbes(_ surface: XCUIElement, horizontal: Bool = false) -> [ScrollAnchor] {
        // Runs outside the measurement window: a full snapshot walks the
        // scrolled subtree on the app main thread, so capturing here keeps
        // that cost out of the reported intervals.
        XCTAssertTrue(surface.exists)
        do {
            return try anchors(in: surface.snapshot(), horizontal: horizontal)
        } catch {
            XCTFail("Could not snapshot scroll content: \(error)")
            return []
        }
    }

    @MainActor
    func performScrollGestures(_ surface: XCUIElement, horizontal: Bool = false) {
        let start = surface.coordinate(withNormalizedOffset: horizontal ? CGVector(dx: 0.8, dy: 0.5) : CGVector(dx: 0.5, dy: 0.75))
        let end = surface.coordinate(withNormalizedOffset: horizontal ? CGVector(dx: 0.2, dy: 0.5) : CGVector(dx: 0.5, dy: 0.25))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        if horizontal {
            surface.swipeLeft(velocity: .fast)
        } else {
            surface.swipeUp(velocity: .fast)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        if horizontal {
            surface.swipeRight(velocity: .fast)
        } else {
            surface.swipeDown(velocity: .fast)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(1))
    }

    @MainActor
    func verifyScrollProbes(
        _ before: [ScrollAnchor],
        _ surface: XCUIElement,
        horizontal: Bool = false,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        // Runs after the measurement finishes so the comparison snapshots do
        // not pollute the reported intervals. A scroll that moved no content
        // still fails as loudly as before.
        let after: [ScrollAnchor]
        do { after = try anchors(in: surface.snapshot(), horizontal: horizontal) }
        catch {
            XCTFail("Could not snapshot scrolled content: \(error)", file: file, line: line)
            return
        }
        let moved = before.contains { anchor in
            let matches = after.filter { $0.key == anchor.key }
            return matches.isEmpty || matches.allSatisfy {
                abs($0.frame.minX - anchor.frame.minX) > 2 || abs($0.frame.minY - anchor.frame.minY) > 2
            }
        }
        if !moved {
            let snapshot = XCTAttachment(screenshot: app.screenshot())
            snapshot.name = "scroll-did-not-move"
            snapshot.lifetime = .keepAlways
            add(snapshot)
            let hierarchy = XCTAttachment(string: surface.debugDescription)
            hierarchy.name = "scroll-surface"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(moved, "Scroll fixture did not expose moving content", file: file, line: line)
    }

    @MainActor
    func exerciseScroll(_ surface: XCUIElement, horizontal: Bool = false) {
        let before = captureScrollProbes(surface, horizontal: horizontal)
        performScrollGestures(surface, horizontal: horizontal)
        verifyScrollProbes(before, surface, horizontal: horizontal)
    }
}
