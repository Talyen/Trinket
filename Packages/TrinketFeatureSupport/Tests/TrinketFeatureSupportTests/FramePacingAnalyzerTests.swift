import Foundation
import Testing
@testable import TrinketFeatureSupport

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
        #expect(abs(report.onePercentLowFPS - 60) < 0.01)
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
        #expect(report.onePercentLowFPS < 120)
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
}
