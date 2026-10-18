import Foundation

/// Bounded interval accumulation; a frozen report never includes later interactions.
public struct FramePacingCapture {
    private let capacity: Int
    private let maximumDuration: TimeInterval
    private var startedAt: TimeInterval?
    private var previousTimestamp: TimeInterval?
    private var intervals: [TimeInterval] = []
    private var expectedDurations: [TimeInterval] = []
    private var overflowed = false
    private var frozen: FramePacingReport?

    public init(capacity: Int = 7200, maximumDuration: TimeInterval = 60) {
        precondition(capacity > 0 && maximumDuration > 0 && maximumDuration.isFinite)
        self.capacity = capacity
        self.maximumDuration = maximumDuration
        intervals.reserveCapacity(capacity)
        expectedDurations.reserveCapacity(capacity)
    }

    public mutating func begin(at timestamp: TimeInterval) {
        precondition(timestamp.isFinite)
        startedAt = timestamp
        previousTimestamp = timestamp
        intervals.removeAll(keepingCapacity: true)
        expectedDurations.removeAll(keepingCapacity: true)
        overflowed = false
        frozen = nil
    }

    public mutating func record(at timestamp: TimeInterval, expectedDuration: TimeInterval) {
        guard frozen == nil, let previousTimestamp,
              timestamp.isFinite, timestamp > previousTimestamp,
              expectedDuration.isFinite, expectedDuration > 0 else { return }
        let interval = timestamp - previousTimestamp
        self.previousTimestamp = timestamp
        guard intervals.count < capacity else { overflowed = true; return }
        intervals.append(interval)
        expectedDurations.append(expectedDuration)
    }

    public mutating func finish(at timestamp: TimeInterval) -> FramePacingReport {
        if let frozen {
            return frozen
        }
        var report = FramePacingAnalyzer.report(intervals: intervals, expectedFrameDurations: expectedDurations)
        report.captureStartedAt = startedAt
        report.captureEndedAt = timestamp
        report.measurementDuration = startedAt.map { timestamp - $0 }
        report.completionStatus = completionStatus(at: timestamp)
        frozen = report
        return report
    }

    private func completionStatus(at timestamp: TimeInterval) -> String {
        if let previousTimestamp, timestamp < previousTimestamp {
            return "invalid-boundary"
        }
        guard startedAt != nil else {
            return "not-started"
        }
        guard let duration = reportDuration(at: timestamp), duration.isFinite, duration > 0 else {
            return "empty"
        }
        if overflowed {
            return "overflow"
        }
        if duration >= maximumDuration {
            return "timeout"
        }
        return intervals.isEmpty ? "empty" : "complete"
    }

    private func reportDuration(at timestamp: TimeInterval) -> TimeInterval? {
        startedAt.map { timestamp - $0 }
    }
}
