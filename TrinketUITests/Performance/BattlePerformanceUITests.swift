import TrinketFeatureSupport
import XCTest

final class BattlePerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func test01RealCardPlay() {
        run(scenario: "real-card-play")
    }

    @MainActor
    func test02HandDragCancel() {
        run(scenario: "hand-drag-cancel")
    }

    @MainActor
    func test03EngineAndHand() {
        run(scenario: "engine-hand")
    }

    @MainActor
    func test04EngineAndFeedback() {
        run(scenario: "engine-feedback")
    }

    @MainActor
    func test05TurnTransition() {
        run(scenario: "turn-transition")
    }

    @MainActor
    func test06CombinedProductionWorstCase() {
        run(scenario: "combined-worst-case")
    }

    @MainActor
    private func run(scenario: String) {
        guard selected(scenario) else { return }
        for iteration in 1 ... repetitionCount {
            runOnce(scenario: scenario, iteration: iteration)
        }
    }

    @MainActor
    private func runOnce(scenario: String, iteration: Int) {
        let arguments = TestLaunchArg.allForBattlePerformance(scenario)
        launchApp(arguments: arguments)
        battle.assertActive(timeout: 8)
        let isPlay = scenario == "real-card-play"
        let isCancel = scenario == "hand-drag-cancel"
        let cards = battle.handCards
        var origin: XCUICoordinate?
        var initialCardCount = 0
        if isPlay || isCancel {
            let card = cards.firstMatch
            assertExists(card)
            origin = screenCoordinate(for: card)
            initialCardCount = cards.count
        }

        let start = button(AccessibilityID.Debug.battlePerformanceStart)
        let status = any(AccessibilityID.Debug.battlePerformanceStatus)
        let stop = measurementControl
        tapWhenReady(start)
        XCTAssertTrue(
            waitUntil(timeout: 4) { (status.value as? String)?.hasPrefix("measuring:\(scenario)") == true },
            "Scenario did not enter its measurement window: \(status.value ?? "missing")",
        )
        if let origin {
            origin.press(forDuration: 0.05, thenDragTo: origin.withOffset(
                isPlay ? CGVector(dx: 0, dy: -120) : CGVector(dx: 48, dy: -20),
            ))
            if isPlay {
                XCTAssertTrue(waitUntil { cards.count == initialCardCount - 1 }, "A successful release did not remove exactly one card")
            } else {
                XCTAssertEqual(cards.count, initialCardCount, "Cancel gestures changed hand membership")
            }
        }
        finishMeasurement(scenario, iteration: iteration, settle: 3, suite: "battle", control: stop)
    }

    private func screenCoordinate(for element: XCUIElement) -> XCUICoordinate {
        let frame = element.frame
        return app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: frame.midX, dy: frame.midY),
        )
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
