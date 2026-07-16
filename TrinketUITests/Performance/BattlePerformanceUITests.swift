import XCTest

/// Full-fidelity Battle workloads. The dedicated runner repeats the matrix and compares
/// raw reports; XCTest's native hitch metric captures the Core Animation render pipeline.
final class BattlePerformanceUITests: TrinketUITestCase {
    private static let scenarioDuration: TimeInterval = 7.2

    func test01Idle() {
        run(scenario: "idle")
    }

    func test02HandDragCancel() {
        run(scenario: "hand-drag-cancel")
    }

    func test03FirstCardCastCold() {
        run(scenario: "first-card-cast-cold")
    }

    func test04RepeatedCardCasts() {
        run(scenario: "repeated-card-casts")
    }

    func test05MaximumConcurrentCasts() {
        run(scenario: "maximum-concurrent-casts")
    }

    func test06DenseFeedback() {
        run(scenario: "dense-feedback")
    }

    func test06aFeedbackChipsOnly() {
        run(scenario: "feedback-chips-only")
    }

    func test06a1FeedbackRasterCold() {
        run(scenario: "feedback-raster-cold")
    }

    func test06a2FeedbackRasterWarm() {
        run(scenario: "feedback-raster-warm")
    }

    func test06bFeedbackReactionsOnly() {
        run(scenario: "feedback-reactions-only")
    }

    func test06cKeywordBurstsOnly() {
        run(scenario: "keyword-bursts-only")
    }

    func test07TurnTransitionAndHandReflow() {
        run(scenario: "turn-transition")
    }

    func test08UltimateCinematic() {
        run(scenario: "ultimate-cinematic")
    }

    func test09AudioPlayback() {
        run(scenario: "audio-playback")
    }

    func test10CombinedWorstCase() {
        run(scenario: "combined-worst-case")
    }

    private func run(scenario: String) {
        launchApp(arguments: TestLaunchArg.allForBattlePerformance(scenario))
        battle.assertActive(timeout: 8)

        let start = app.buttons[AccessibilityID.Debug.battlePerformanceStart]
        XCTAssertTrue(start.waitForExistence(timeout: Self.defaultTimeout))
        let status = app.descendants(matching: .any)[AccessibilityID.Debug.battlePerformanceStatus]
        XCTAssertTrue(status.waitForExistence(timeout: Self.defaultTimeout))
        let metrics = app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
        XCTAssertTrue(metrics.waitForExistence(timeout: Self.defaultTimeout))

        tapWhenReady(start)
        RunLoop.current.run(until: Date().addingTimeInterval(Self.scenarioDuration))
        let rasterStatus = status.value as? String ?? ""
        XCTAssertTrue(
            rasterStatus.hasPrefix("complete:\(scenario):"),
            "Scenario did not complete: \(rasterStatus)"
        )
        guard let payload = metrics.value as? String,
              let report = FramePacingReport.parseAccessibilityValue(payload) else {
            XCTFail("No measured frame report was captured for \(scenario)")
            return
        }
        XCTAssertGreaterThanOrEqual(
            report.sampleCount,
            120,
            "Sampler did not capture enough delivered frames: \(report.accessibilityValue)"
        )
        record(report: report, scenario: scenario, iteration: 1, rasterStatus: rasterStatus)
    }

    private func record(
        report: FramePacingReport,
        scenario: String,
        iteration: Int,
        rasterStatus: String
    ) {
        PerformanceReportRecorder.record(
            report,
            scenario: scenario,
            suite: "battle",
            iteration: iteration,
            metadata: ["rasterStatus": rasterStatus],
            in: self
        )
    }
}
