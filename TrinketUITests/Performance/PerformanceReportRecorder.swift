import Foundation
import XCTest

enum PerformanceReportRecorder {
    static func record(
        _ report: FramePacingReport,
        scenario: String,
        suite: String,
        iteration: Int,
        metadata: [String: String] = [:],
        in testCase: XCTestCase
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
