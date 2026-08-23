import Foundation

/// Display-link pacing normalized to the refresh period observed during the sample.
/// This report supplies raw, scenario-addressable diagnostics; it is not an
/// authoritative render-pipeline hitch metric.
public struct FramePacingReport: Equatable, Sendable {
    public static let schemaVersion = 4

    public var sampleCount: Int
    public var expectedFPS: Double
    public var averageFPS: Double
    public var p95FrameMs: Double
    public var p99FrameMs: Double
    public var onePercentLowFPS: Double
    public var maxFrameMs: Double
    public var missedDeadlineCount: Int
    public var estimatedMissedFrameCount: Int
    public var severeStallCount: Int
    public var missedDeadlineRatio: Double

    public static let empty = Self(
        sampleCount: 0,
        expectedFPS: 0,
        averageFPS: 0,
        p95FrameMs: 0,
        p99FrameMs: 0,
        onePercentLowFPS: 0,
        maxFrameMs: 0,
        missedDeadlineCount: 0,
        estimatedMissedFrameCount: 0,
        severeStallCount: 0,
        missedDeadlineRatio: 0
    )

    public init(
        sampleCount: Int,
        expectedFPS: Double,
        averageFPS: Double,
        p95FrameMs: Double,
        p99FrameMs: Double,
        onePercentLowFPS: Double,
        maxFrameMs: Double,
        missedDeadlineCount: Int,
        estimatedMissedFrameCount: Int,
        severeStallCount: Int,
        missedDeadlineRatio: Double
    ) {
        self.sampleCount = sampleCount
        self.expectedFPS = expectedFPS
        self.averageFPS = averageFPS
        self.p95FrameMs = p95FrameMs
        self.p99FrameMs = p99FrameMs
        self.onePercentLowFPS = onePercentLowFPS
        self.maxFrameMs = maxFrameMs
        self.missedDeadlineCount = missedDeadlineCount
        self.estimatedMissedFrameCount = estimatedMissedFrameCount
        self.severeStallCount = severeStallCount
        self.missedDeadlineRatio = missedDeadlineRatio
    }

    /// Compact machine-readable payload fetched once after a UI performance scenario.
    public var accessibilityValue: String {
        String(
            format: "schema=%d;samples=%d;expectedFPS=%.2f;avgFPS=%.2f;p95Ms=%.2f;p99Ms=%.2f;oneLowFPS=%.2f;maxMs=%.2f;missed=%d;estimatedMissed=%d;severe=%d;missedRatio=%.5f",
            Self.schemaVersion,
            sampleCount,
            expectedFPS,
            averageFPS,
            p95FrameMs,
            p99FrameMs,
            onePercentLowFPS,
            maxFrameMs,
            missedDeadlineCount,
            estimatedMissedFrameCount,
            severeStallCount,
            missedDeadlineRatio
        )
    }

    public static func parseAccessibilityValue(_ value: String) -> Self? {
        var map: [String: String] = [:]
        for part in value.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            map[String(pair[0])] = String(pair[1])
        }
        guard
            map["schema"].flatMap(Int.init) == schemaVersion,
            let samples = map["samples"].flatMap(Int.init),
            let expectedFPS = map["expectedFPS"].flatMap(Double.init),
            let averageFPS = map["avgFPS"].flatMap(Double.init),
            let p95FrameMs = map["p95Ms"].flatMap(Double.init),
            let p99FrameMs = map["p99Ms"].flatMap(Double.init),
            let onePercentLowFPS = map["oneLowFPS"].flatMap(Double.init),
            let maxFrameMs = map["maxMs"].flatMap(Double.init),
            let missedDeadlineCount = map["missed"].flatMap(Int.init),
            let estimatedMissedFrameCount = map["estimatedMissed"].flatMap(Int.init),
            let severeStallCount = map["severe"].flatMap(Int.init),
            let missedDeadlineRatio = map["missedRatio"].flatMap(Double.init)
        else { return nil }

        return Self(
            sampleCount: samples,
            expectedFPS: expectedFPS,
            averageFPS: averageFPS,
            p95FrameMs: p95FrameMs,
            p99FrameMs: p99FrameMs,
            onePercentLowFPS: onePercentLowFPS,
            maxFrameMs: maxFrameMs,
            missedDeadlineCount: missedDeadlineCount,
            estimatedMissedFrameCount: estimatedMissedFrameCount,
            severeStallCount: severeStallCount,
            missedDeadlineRatio: missedDeadlineRatio
        )
    }
}

public enum FramePacingAnalyzer {
    /// Half-period tolerance separates actual missed presentation opportunities from
    /// small CADisplayLink / Simulator scheduling jitter.
    static let missedDeadlinePeriodMultiplier = 1.5
    /// Three display periods is a separately reported severe stall at either 60 or 120 Hz.
    static let severeStallPeriodMultiplier = 3.0

    public static func report(
        intervals: [CFTimeInterval],
        expectedFrameDurations: [CFTimeInterval]
    ) -> FramePacingReport {
        guard !intervals.isEmpty else { return .empty }

        let validExpectedDurations = expectedFrameDurations.filter { $0 > 0 && $0.isFinite }
        let expectedFrameDuration = median(validExpectedDurations)
        guard expectedFrameDuration > 0 else { return .empty }

        let sorted = intervals.filter { $0 > 0 && $0.isFinite }.sorted()
        guard !sorted.isEmpty else { return .empty }

        let averageDuration = sorted.reduce(0, +) / Double(sorted.count)
        let missedDeadlineThreshold = expectedFrameDuration * missedDeadlinePeriodMultiplier
        let severeStallThreshold = expectedFrameDuration * severeStallPeriodMultiplier
        let missedDeadlineCount = sorted.count { $0 >= missedDeadlineThreshold }
        let estimatedMissedFrameCount = sorted.reduce(into: 0) { total, interval in
            let deliveredPeriods = max(1, Int((interval / expectedFrameDuration).rounded()))
            total += max(0, deliveredPeriods - 1)
        }

        return FramePacingReport(
            sampleCount: sorted.count,
            expectedFPS: 1.0 / expectedFrameDuration,
            averageFPS: 1.0 / averageDuration,
            p95FrameMs: percentile(sorted, fraction: 0.95) * 1000,
            p99FrameMs: percentile(sorted, fraction: 0.99) * 1000,
            onePercentLowFPS: lowFPS(sorted, worstFraction: 0.01),
            maxFrameMs: (sorted.last ?? 0) * 1000,
            missedDeadlineCount: missedDeadlineCount,
            estimatedMissedFrameCount: estimatedMissedFrameCount,
            severeStallCount: sorted.count { $0 >= severeStallThreshold },
            missedDeadlineRatio: Double(missedDeadlineCount) / Double(sorted.count)
        )
    }

    private static func percentile(_ sorted: [CFTimeInterval], fraction: Double) -> CFTimeInterval {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, max(0, Int((Double(sorted.count - 1) * fraction).rounded(.up))))
        return sorted[index]
    }

    private static func median(_ values: [CFTimeInterval]) -> CFTimeInterval {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let midpoint = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[midpoint - 1] + sorted[midpoint]) / 2
        }
        return sorted[midpoint]
    }

    /// Average FPS delivered by the slowest fraction of frames. This is deliberately
    /// duration-based, so a small number of long stalls cannot hide behind average FPS.
    private static func lowFPS(
        _ sorted: [CFTimeInterval],
        worstFraction: Double
    ) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let count = min(sorted.count, max(1, Int((Double(sorted.count) * worstFraction).rounded(.up))))
        let worst = sorted.suffix(count)
        let averageDuration = worst.reduce(0, +) / Double(count)
        return averageDuration > 0 ? 1.0 / averageDuration : 0
    }
}
