import Foundation
import Testing
@testable import Trinket

struct FramePacingAnalyzerTests {
    @Test func emptyIntervalsYieldEmptyReport() {
        let report = FramePacingAnalyzer.report(intervals: [])
        #expect(report == .empty)
    }

    @Test func steadySixtyHzHasNoDeadlineMisses() {
        let intervals = Array(repeating: 1.0 / 60.0, count: 1000)
        let report = FramePacingAnalyzer.report(intervals: intervals)

        #expect(report.sampleCount == 1000)
        #expect(abs(report.expectedFPS - 60) < 0.01)
        #expect(abs(report.averageFPS - 60) < 0.01)
        #expect(report.missedDeadlineCount == 0)
        #expect(report.estimatedMissedFrameCount == 0)
        #expect(report.severeStallCount == 0)
        #expect(report.missedDeadlineRatio == 0)
        #expect(abs(report.p99FrameMs - (1000.0 / 60.0)) < 0.01)
        #expect(abs(report.p999FrameMs - (1000.0 / 60.0)) < 0.01)
        #expect(abs(report.onePercentLowFPS - 60) < 0.01)
        #expect(abs(report.pointOnePercentLowFPS - 60) < 0.01)
    }

    @Test func missedFramesAndSevereStallsAreRefreshNormalized() {
        var intervals = Array(repeating: 1.0 / 120.0, count: 990)
        intervals += Array(repeating: 2.0 / 120.0, count: 9)
        intervals.append(4.0 / 120.0)

        let report = FramePacingAnalyzer.report(
            intervals: intervals,
            expectedFrameDuration: 1.0 / 120.0
        )

        #expect(abs(report.expectedFPS - 120) < 0.01)
        #expect(report.missedDeadlineCount == 10)
        #expect(report.estimatedMissedFrameCount == 12)
        #expect(report.severeStallCount == 1)
        #expect(abs(report.missedDeadlineRatio - 0.01) < 0.000_01)
        #expect(abs(report.maxFrameMs - (4000.0 / 120.0)) < 0.01)
        #expect(report.p99FrameMs >= (2000.0 / 120.0) - 0.01)
        #expect(report.p999FrameMs >= (4000.0 / 120.0) - 0.01)
        #expect(report.onePercentLowFPS < 120)
        #expect(report.pointOnePercentLowFPS < report.onePercentLowFPS)
    }

    @Test func subHalfPeriodJitterDoesNotCountAsADeadlineMiss() {
        let period = 1.0 / 60.0
        let report = FramePacingAnalyzer.report(
            intervals: [period, period * 1.49, period],
            expectedFrameDuration: period
        )

        #expect(report.missedDeadlineCount == 0)
        #expect(report.estimatedMissedFrameCount == 0)
    }

    @Test func accessibilityValueRoundTrips() {
        let original = FramePacingReport(
            sampleCount: 600,
            expectedFPS: 60,
            averageFPS: 59.4,
            p95FrameMs: 16.9,
            p99FrameMs: 22.5,
            p999FrameMs: 31.2,
            onePercentLowFPS: 48.4,
            pointOnePercentLowFPS: 32.1,
            maxFrameMs: 35.1,
            missedDeadlineCount: 2,
            estimatedMissedFrameCount: 2,
            severeStallCount: 0,
            missedDeadlineRatio: 2.0 / 600.0
        )

        let parsed = FramePacingReport.parseAccessibilityValue(original.accessibilityValue)
        #expect(parsed != nil)
        #expect(parsed?.sampleCount == 600)
        #expect(parsed?.missedDeadlineCount == 2)
        #expect(parsed?.estimatedMissedFrameCount == 2)
        #expect(parsed?.severeStallCount == 0)
        #expect(abs((parsed?.averageFPS ?? 0) - 59.4) < 0.01)
        #expect(abs((parsed?.p99FrameMs ?? 0) - 22.5) < 0.01)
        #expect(abs((parsed?.p999FrameMs ?? 0) - 31.2) < 0.01)
        #expect(abs((parsed?.onePercentLowFPS ?? 0) - 48.4) < 0.01)
        #expect(abs((parsed?.pointOnePercentLowFPS ?? 0) - 32.1) < 0.01)
        #expect(abs((parsed?.missedDeadlineRatio ?? 0) - (2.0 / 600.0)) < 0.000_01)
    }
}
