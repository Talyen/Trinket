import Foundation
import TrinketFeatureSupport
import XCTest

enum PerformanceReportRecorder {
    @MainActor
    static func capture(
        from app: XCUIApplication,
        scenario: String,
        suite: String,
        iteration: Int,
        metadata: [String: String] = [:],
        in testCase: XCTestCase,
    ) {
        let metrics = app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
        var captured: FramePacingReport?
        let completed = NSPredicate { _, _ in
            guard let payload = metrics.value as? String,
                  let report = FramePacingReport.parseAccessibilityValue(payload)
            else { return false }
            captured = report
            return true
        }
        let result = XCTWaiter().wait(
            for: [XCTNSPredicateExpectation(predicate: completed, object: metrics)],
            timeout: 12,
        )
        guard result == .completed, let report = captured else {
            XCTFail("Frame snapshot did not complete for \(scenario); last=\(metrics.value ?? "nil")")
            return
        }

        record(report, scenario: scenario, suite: suite, iteration: iteration, metadata: metadata, in: testCase)
        XCTAssertTrue(
            report.coversMeasurement(seconds: FramePacingMeasurementTiming.snapshotSeconds),
            "Incomplete frame measurement for \(scenario): duration=\(String(describing: report.measurementDuration)), samples=\(report.sampleCount)",
        )
    }

    static func record(
        _ report: FramePacingReport,
        scenario: String,
        suite: String,
        iteration: Int,
        metadata: [String: String] = [:],
        in testCase: XCTestCase,
    ) {
        let environment = ProcessInfo.processInfo.environment
        var object: [String: Any] = [
            "schemaVersion": FramePacingReport.schemaVersion,
            "runID": UUID().uuidString,
            "suite": suite,
            "scenario": scenario,
            "iteration": iteration,
            "capturedAt": ISO8601DateFormatter().string(from: .now),
            "simulatorModel": environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown",
            "simulatorRuntime": environment["SIMULATOR_RUNTIME_VERSION"] ?? "unknown",
            "sampleCount": report.sampleCount,
            "sampledDuration": report.sampledDuration,
            "expectedFPS": report.expectedFPS,
            "averageFPS": report.averageFPS,
            "p95FrameMs": report.p95FrameMs,
            "p99FrameMs": report.p99FrameMs,
            "onePercentLowFPS": report.onePercentLowFPS,
            "maxFrameMs": report.maxFrameMs,
            "missedDeadlineCount": report.missedDeadlineCount,
            "estimatedMissedFrameCount": report.estimatedMissedFrameCount,
            "severeStallCount": report.severeStallCount,
            "missedDeadlineRatio": report.missedDeadlineRatio,
        ]
        if let duration = report.measurementDuration {
            object["measurementDuration"] = duration
        }
        for (key, value) in metadata {
            object[key] = value
        }

        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            XCTFail("Could not encode performance report")
            return
        }

        let attachment = XCTAttachment(string: json)
        attachment.name = "performance-\(scenario)-\(iteration).json"
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
        print("TRINKET_PERFORMANCE_REPORT \(json)")
    }
}
