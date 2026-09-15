import Testing
@testable import TrinketFeatureSupport

struct FramePacingCaptureTests {
    @Test func `explicit boundaries retain first stall and freeze evidence`() {
        var capture = FramePacingCapture()
        capture.record(at: 90, expectedDuration: 1.0 / 60)
        capture.begin(at: 100)
        capture.record(at: 100.12, expectedDuration: 1.0 / 60)
        capture.record(at: 100.14, expectedDuration: 1.0 / 60)
        let report = capture.finish(at: 100.15)
        #expect(report.completionStatus == "complete")
        #expect(report.sampleCount == 2)
        #expect(report.severeStallCount == 1)
        #expect(report.maxFrameMs > 119)
        capture.record(at: 101, expectedDuration: 1.0 / 60)
        #expect(capture.finish(at: 102) == report)
        capture.begin(at: 200)
        capture.record(at: 200.02, expectedDuration: 1.0 / 60)
        #expect(capture.finish(at: 200.01).completionStatus == "invalid-boundary")
    }

    @Test func `unstarted empty timed out and overflowed captures stay distinct`() {
        var capture = FramePacingCapture(capacity: 2, maximumDuration: 1)
        #expect(capture.finish(at: 1).completionStatus == "not-started")
        capture.begin(at: 2)
        #expect(capture.finish(at: 2).completionStatus == "empty")
        capture.begin(at: 2)
        #expect(capture.finish(at: 2.1).sampleCount == 0)
        #expect(capture.finish(at: 2.1).completionStatus == "empty")
        capture.begin(at: 3)
        capture.record(at: 3.02, expectedDuration: 1.0 / 60)
        #expect(capture.finish(at: 4).completionStatus == "timeout")
        capture.begin(at: 5)
        for timestamp in [5.02, 5.04, 5.06] {
            capture.record(at: timestamp, expectedDuration: 1.0 / 60)
        }
        let overflow = capture.finish(at: 5.1)
        #expect(overflow.completionStatus == "overflow")
        #expect(overflow.sampleCount == 2)
    }

    @Test func `invalid callbacks do not replace the last valid timestamp`() {
        var capture = FramePacingCapture()
        capture.begin(at: 10)
        capture.record(at: 9, expectedDuration: 1.0 / 60)
        capture.record(at: 10.01, expectedDuration: .nan)
        capture.record(at: .infinity, expectedDuration: 1.0 / 60)
        capture.record(at: 10.12, expectedDuration: 1.0 / 60)
        let report = capture.finish(at: 10.13)
        #expect(report.sampleCount == 1)
        #expect(report.maxFrameMs > 119)
        #expect(FramePacingReport.parseAccessibilityValue(report.accessibilityValue) == report)
    }
}
