import TrinketFeatureSupport
import XCTest

class PerformanceJourneyUITestCase: TrinketUITestCase {
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
            // Unmeasured prerequisites still prepare a later selected step.
            action()
            return
        }
        let control = measurementControl
        control.tap()
        waitForMeasurementState("ready")
        control.tap()
        waitForMeasurementState("measuring")
        action()
        finishMeasurement(scenario, iteration: iteration, settle: settle, control: control)
    }

    @MainActor
    func measured(_ scenario: String, iteration: Int, scrolling surface: XCUIElement) {
        guard selected(scenario) else { return }
        let probes = captureScrollProbes(surface)
        measured(scenario, iteration: iteration) { performScrollGestures(surface) }
        verifyScrollProbes(probes, surface)
    }

    var measurementControl: XCUICoordinate {
        let control = app.buttons[AccessibilityID.Debug.frameMetricsReset]
        XCTAssertTrue(control.trinketWaitForExistence(timeout: Self.defaultTimeout))
        return control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }

    func waitForMeasurementState(_ state: String) {
        let metrics = app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", state), object: metrics)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 4), .completed)
    }

    @MainActor
    func finishMeasurement(
        _ scenario: String,
        iteration: Int,
        settle: TimeInterval = 1.5,
        suite: String = "app",
        control: XCUICoordinate? = nil,
    ) {
        RunLoop.current.run(until: Date().addingTimeInterval(settle))
        // A watchdog result is a failure, never a new capture or an accepted late action.
        let metrics = app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
        XCTAssertEqual(metrics.value as? String, "measuring", "Capture ended before interaction: \(scenario)")
        (control ?? measurementControl).tap()
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

    struct ScrollAnchor {
        let key: String
        let frame: CGRect
    }

    @MainActor
    private func anchors(in snapshot: any XCUIElementSnapshot) -> [ScrollAnchor] {
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
               frame.height < viewport.height * 0.9,
               frame.intersects(viewport) {
                result.append(ScrollAnchor(key: "\(child.elementType.rawValue):\(child.identifier):\(child.label)", frame: frame))
            }
        }
        return result
    }

    @MainActor
    func captureScrollProbes(_ surface: XCUIElement) -> [ScrollAnchor] {
        // Runs outside the measurement window: a full snapshot walks the
        // scrolled subtree on the app main thread, so capturing here keeps
        // that cost out of the reported intervals.
        XCTAssertTrue(surface.exists)
        do {
            return try anchors(in: surface.snapshot())
        } catch {
            XCTFail("Could not snapshot scroll content: \(error)")
            return []
        }
    }

    @MainActor
    func performScrollGestures(_ surface: XCUIElement) {
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        surface.swipeUp(velocity: .fast)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
    }

    @MainActor
    func verifyScrollProbes(
        _ before: [ScrollAnchor],
        _ surface: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        // Runs after the measurement finishes so the comparison snapshots do
        // not pollute the reported intervals. A scroll that moved no content
        // still fails as loudly as before.
        let after: [ScrollAnchor]
        do { after = try anchors(in: surface.snapshot()) }
        catch {
            XCTFail("Could not snapshot scrolled content: \(error)", file: file, line: line)
            return
        }
        let moved = scrollAnchorsMoved(from: before, to: after)
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

    private func scrollAnchorsMoved(from before: [ScrollAnchor], to after: [ScrollAnchor]) -> Bool {
        before.contains { anchor in
            let matches = after.filter { $0.key == anchor.key }
            return matches.isEmpty || matches.allSatisfy {
                abs($0.frame.minX - anchor.frame.minX) > 2 || abs($0.frame.minY - anchor.frame.minY) > 2
            }
        }
    }
}
