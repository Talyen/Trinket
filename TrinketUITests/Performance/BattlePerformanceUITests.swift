import XCTest

/// Full-fidelity Battle workloads. The dedicated runner repeats the matrix and compares
/// raw reports; XCTest's native hitch metric captures the Core Animation render pipeline.
final class BattlePerformanceUITests: TrinketUITestCase {
    private static var scenarioDuration: TimeInterval {
        // Mirror `BattlePerformanceTiming.uiTestWaitSeconds` (UITest target cannot import app).
        ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1" ? 3.2 : 7.2
    }

    private var repetitionCount: Int {
        let raw = ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_REPETITIONS"] ?? "1"
        return max(1, Int(raw) ?? 1)
    }

    func test01Idle() {
        run(scenario: "idle")
    }

    func test02HandDragCancel() {
        run(scenario: "hand-drag-cancel")
    }

    func test03FirstCardCastCold() {
        run(scenario: "first-card-cast-cold")
    }

    func test03bRealCardPlay() {
        run(scenario: "real-card-play")
    }

    func test03cPlayEngineHand() {
        run(scenario: "play-engine-hand")
    }

    func test03dPlayFeedbackOnly() {
        run(scenario: "play-feedback-only")
    }

    func test03ePlayCastOnly() {
        run(scenario: "play-cast-only")
    }

    func test03e1PlayCastFaceOnly() {
        run(scenario: "play-cast-face-only")
    }

    func test03e2PlayCastMaskOnly() {
        run(scenario: "play-cast-mask-only")
    }

    func test03e3PlayCastParticlesOnly() {
        run(scenario: "play-cast-particles-only")
    }

    func test03fPlaySwingOnly() {
        run(scenario: "play-swing-only")
    }

    func test03gPlayStackDirect() {
        run(scenario: "play-stack-direct")
    }

    func test03g1PlayStackNoSwing() {
        run(scenario: "play-stack-no-swing")
    }

    func test03g2PlayStackNoFeedback() {
        run(scenario: "play-stack-no-feedback")
    }

    func test03g3PlayStackNoCast() {
        run(scenario: "play-stack-no-cast")
    }

    func test03hPlayRealNoCast() {
        run(scenario: "play-real-no-cast")
    }

    func test03h1PlayRealNoSwing() {
        run(scenario: "play-real-no-swing")
    }

    func test03h2PlayRealNoFeedback() {
        run(scenario: "play-real-no-feedback")
    }

    func test03iPlayCastHeldPose() {
        run(scenario: "play-cast-held-pose")
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
        for iteration in 1 ... repetitionCount {
            runOnce(scenario: scenario, iteration: iteration)
        }
    }

    private func runOnce(scenario: String, iteration: Int) {
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
        let minimumSamples = ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1"
            ? 60
            : 120
        XCTAssertGreaterThanOrEqual(
            report.sampleCount,
            minimumSamples,
            "Sampler did not capture enough delivered frames: \(report.accessibilityValue)"
        )
        record(report: report, scenario: scenario, iteration: iteration, rasterStatus: rasterStatus)
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
