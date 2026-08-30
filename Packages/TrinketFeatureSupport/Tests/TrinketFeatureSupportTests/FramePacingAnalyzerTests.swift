import Foundation
import Testing
@testable import TrinketFeatureSupport

struct FramePacingAnalyzerTests {
    @Test func `empty intervals yield empty report`() {
        let report = FramePacingAnalyzer.report(intervals: [], expectedFrameDurations: [])
        #expect(report == .empty)
    }

    @Test func `steady sixty hz has no deadline misses`() {
        let intervals = Array(repeating: 1.0 / 60.0, count: 1000)
        let report = FramePacingAnalyzer.report(
            intervals: intervals,
            expectedFrameDurations: Array(repeating: 1.0 / 60.0, count: intervals.count),
        )

        #expect(report.sampleCount == 1000)
        #expect(abs(report.expectedFPS - 60) < 0.01)
        #expect(abs(report.averageFPS - 60) < 0.01)
        #expect(report.missedDeadlineCount == 0)
        #expect(report.estimatedMissedFrameCount == 0)
        #expect(report.severeStallCount == 0)
        #expect(report.missedDeadlineRatio == 0)
        #expect(abs(report.p99FrameMs - (1000.0 / 60.0)) < 0.01)
        #expect(abs(report.onePercentLowFPS - 60) < 0.01)
    }

    @Test func `missed frames and severe stalls are refresh normalized`() {
        var intervals = Array(repeating: 1.0 / 120.0, count: 990)
        intervals += Array(repeating: 2.0 / 120.0, count: 9)
        intervals.append(4.0 / 120.0)

        let report = FramePacingAnalyzer.report(
            intervals: intervals,
            expectedFrameDurations: Array(repeating: 1.0 / 120.0, count: intervals.count),
        )

        #expect(abs(report.expectedFPS - 120) < 0.01)
        #expect(report.missedDeadlineCount == 10)
        #expect(report.estimatedMissedFrameCount == 12)
        #expect(report.severeStallCount == 1)
        #expect(abs(report.missedDeadlineRatio - 0.01) < 0.000_01)
        #expect(abs(report.maxFrameMs - (4000.0 / 120.0)) < 0.01)
        #expect(abs(report.p95FrameMs - (1000.0 / 120.0)) < 0.01)
        #expect(abs(report.p99FrameMs - (1000.0 / 120.0)) < 0.01)
        #expect(report.onePercentLowFPS < 120)
    }

    @Test func `sub half period jitter does not count as A deadline miss`() {
        let period = 1.0 / 60.0
        let report = FramePacingAnalyzer.report(
            intervals: [period, period * 1.49, period],
            expectedFrameDurations: Array(repeating: period, count: 3),
        )

        #expect(report.missedDeadlineCount == 0)
        #expect(report.estimatedMissedFrameCount == 0)
    }

    @Test func `accessibility value round trips the current schema`() {
        let report = FramePacingReport(
            sampleCount: 120,
            expectedFPS: 60,
            averageFPS: 59.5,
            p95FrameMs: 18.2,
            p99FrameMs: 21.4,
            onePercentLowFPS: 48.1,
            maxFrameMs: 33.3,
            missedDeadlineCount: 2,
            estimatedMissedFrameCount: 3,
            severeStallCount: 1,
            missedDeadlineRatio: 0.01667,
        )
        let parsed = FramePacingReport.parseAccessibilityValue(report.accessibilityValue)
        #expect(parsed?.accessibilityValue == report.accessibilityValue)
        let legacyValue = report.accessibilityValue.replacingOccurrences(of: "schema=5", with: "schema=4")
        #expect(FramePacingReport.parseAccessibilityValue(legacyValue) != nil)
        #expect(FramePacingReport.parseAccessibilityValue("schema=3;samples=1") == nil)
    }
}
