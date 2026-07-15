import XCTest

/// Full-fidelity Battle workloads. The dedicated runner repeats the matrix and compares
/// raw reports; XCTest's native hitch metric captures the Core Animation render pipeline.
final class BattlePerformanceUITests: TrinketUITestCase {
    private static let scenarioDuration: TimeInterval = 6.8

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

        let options = XCTMeasureOptions()
        options.iterationCount = 1
        var capturedReports: [FramePacingReport] = []
        var capturedStatuses: [String] = []
        measure(
            metrics: [XCTHitchMetric(application: app)],
            options: options
        ) {
            tapWhenReady(start)
            RunLoop.current.run(until: Date().addingTimeInterval(Self.scenarioDuration))
            capturedStatuses.append(status.value as? String ?? "")
            if let payload = metrics.value as? String,
               let report = FramePacingReport.parseAccessibilityValue(payload) {
                capturedReports.append(report)
            }
        }

        // XCTest may invoke the block once for calibration before its measured iteration.
        XCTAssertFalse(capturedReports.isEmpty)
        XCTAssertEqual(capturedStatuses.count, capturedReports.count)
        for (index, statusValue) in capturedStatuses.enumerated() {
            XCTAssertTrue(
                statusValue.hasPrefix("complete:\(scenario):"),
                "Scenario iteration \(index + 1) did not complete: \(statusValue)"
            )
        }
        for (index, report) in capturedReports.enumerated() {
            XCTAssertGreaterThanOrEqual(
                report.sampleCount,
                120,
                "Sampler did not capture enough delivered frames: \(report.accessibilityValue)"
            )
            record(report: report, scenario: scenario, iteration: index + 1)
        }
    }

    private func record(report: FramePacingReport, scenario: String, iteration: Int) {
        let environment = ProcessInfo.processInfo.environment
        let object: [String: Any] = [
            "schemaVersion": FramePacingReport.schemaVersion,
            "runID": UUID().uuidString,
            "scenario": scenario,
            "iteration": iteration,
            "capturedAt": ISO8601DateFormatter().string(from: .now),
            "simulatorModel": environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown",
            "simulatorRuntime": environment["SIMULATOR_RUNTIME_VERSION"] ?? "unknown",
            "sampleCount": report.sampleCount,
            "expectedFPS": report.expectedFPS,
            "averageFPS": report.averageFPS,
            "p95FrameMs": report.p95FrameMs,
            "p99FrameMs": report.p99FrameMs,
            "p999FrameMs": report.p999FrameMs,
            "onePercentLowFPS": report.onePercentLowFPS,
            "pointOnePercentLowFPS": report.pointOnePercentLowFPS,
            "maxFrameMs": report.maxFrameMs,
            "missedDeadlineCount": report.missedDeadlineCount,
            "estimatedMissedFrameCount": report.estimatedMissedFrameCount,
            "severeStallCount": report.severeStallCount,
            "missedDeadlineRatio": report.missedDeadlineRatio
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            XCTFail("Could not encode performance report")
            return
        }

        let attachment = XCTAttachment(string: json)
        attachment.name = "battle-performance-\(scenario)-\(iteration).json"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("TRINKET_PERFORMANCE_REPORT \(json)")
    }
}
