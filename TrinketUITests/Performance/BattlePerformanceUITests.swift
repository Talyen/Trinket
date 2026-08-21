import TrinketFeatureSupport
import XCTest

/// Battle frame-pacing gates. Real play and drag handling use actual XCUI gestures;
/// component scenarios isolate which synchronous stage still misses the budget.
final class BattlePerformanceUITests: TrinketUITestCase {
    private static var scenarioDuration: TimeInterval {
        // Keep ≥ app `BattlePerformanceTiming.snapshotDelay` (10s full / 3s quick).
        ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1" ? 3.2 : 10.5
    }

    private var repetitionCount: Int {
        let raw = ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_REPETITIONS"] ?? "1"
        return max(1, Int(raw) ?? 1)
    }

    func test01RealCardPlay() {
        run(scenario: "real-card-play")
    }

    func test02HandDragCancel() {
        run(scenario: "hand-drag-cancel")
    }

    func test03EngineAndHand() {
        run(scenario: "engine-hand")
    }

    func test04EngineAndFeedback() {
        run(scenario: "engine-feedback")
    }

    func test05TurnTransition() {
        run(scenario: "turn-transition")
    }

    func test06CombinedProductionWorstCase() {
        run(scenario: "combined-worst-case")
    }

    private func run(scenario: String) {
        for iteration in 1 ... repetitionCount {
            runOnce(scenario: scenario, iteration: iteration)
        }
    }

    private func runOnce(scenario: String, iteration: Int) {
        launchApp(arguments: TestLaunchArg.allForBattlePerformance(scenario))
        battle.assertActive(timeout: 8)
        let gesture = prepareGesture(for: scenario)

        let start = app.buttons[AccessibilityID.Debug.battlePerformanceStart]
        XCTAssertTrue(start.waitForExistence(timeout: Self.defaultTimeout))
        let status = app.descendants(matching: .any)[AccessibilityID.Debug.battlePerformanceStatus]
        XCTAssertTrue(status.waitForExistence(timeout: Self.defaultTimeout))
        let metrics = app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
        XCTAssertTrue(metrics.waitForExistence(timeout: Self.defaultTimeout))

        tapWhenReady(start)
        XCTAssertTrue(
            waitForStatus(status, prefix: "measuring:\(scenario)"),
            "Scenario did not enter its measurement window: \(status.value ?? "missing")"
        )
        perform(gesture)
        RunLoop.current.run(until: Date().addingTimeInterval(Self.scenarioDuration))

        let scenarioStatus = status.value as? String ?? ""
        XCTAssertTrue(
            scenarioStatus.hasPrefix("complete:\(scenario):"),
            "Scenario did not complete: \(scenarioStatus)"
        )
        validate(gesture)
        guard let payload = metrics.value as? String,
              let report = FramePacingReport.parseAccessibilityValue(payload) else {
            XCTFail("No measured frame report was captured for \(scenario)")
            return
        }
        let minimumSamples = ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1"
            ? 60
            : 90
        XCTAssertGreaterThanOrEqual(report.sampleCount, minimumSamples)
        PerformanceReportRecorder.record(
            report,
            scenario: scenario,
            suite: "battle",
            iteration: iteration,
            metadata: ["scenarioStatus": scenarioStatus],
            in: self
        )
    }

    private enum Gesture {
        case none
        case play(origin: XCUICoordinate, initialCardCount: Int)
        case cancel(origin: XCUICoordinate, initialCardCount: Int)
    }

    private func prepareGesture(for scenario: String) -> Gesture {
        switch scenario {
        case "real-card-play":
            let cards = handCards()
            let card = cards.firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: Self.defaultTimeout))
            return .play(origin: screenCoordinate(for: card), initialCardCount: cards.count)
        case "hand-drag-cancel":
            let cards = handCards()
            let card = cards.firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: Self.defaultTimeout))
            return .cancel(origin: screenCoordinate(for: card), initialCardCount: cards.count)
        default:
            return .none
        }
    }

    private func perform(_ gesture: Gesture) {
        switch gesture {
        case .none:
            return
        case let .play(origin, _):
            drag(from: origin, offset: CGVector(dx: 0, dy: -120))
        case let .cancel(origin, _):
            drag(from: origin, offset: CGVector(dx: 48, dy: -20))
        }
    }

    private func validate(_ gesture: Gesture) {
        switch gesture {
        case .none:
            return
        case let .play(_, initialCardCount):
            XCTAssertTrue(
                waitUntil { self.handCards().count == initialCardCount - 1 },
                "A successful release did not remove exactly one card"
            )
        case let .cancel(_, initialCardCount):
            XCTAssertEqual(
                handCards().count,
                initialCardCount,
                "Cancel gestures changed hand membership"
            )
        }
    }

    private func handCards() -> XCUIElementQuery {
        BattleScreen(app: app).handCards
    }

    private func screenCoordinate(for element: XCUIElement) -> XCUICoordinate {
        let frame = element.frame
        return app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: frame.midX, dy: frame.midY)
        )
    }

    private func drag(from origin: XCUICoordinate, offset: CGVector) {
        origin.press(forDuration: 0.05, thenDragTo: origin.withOffset(offset))
    }

    private func waitForStatus(
        _ element: XCUIElement,
        prefix: String,
        timeout: TimeInterval = 4
    ) -> Bool {
        waitUntil(timeout: timeout) { (element.value as? String)?.hasPrefix(prefix) == true }
    }

    private func waitUntil(timeout: TimeInterval = 3, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return condition()
    }
}
