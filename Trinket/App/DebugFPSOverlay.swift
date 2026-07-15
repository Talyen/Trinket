#if DEBUG
import QuartzCore
import SwiftUI
import TrinketDesignSystem

enum DebugPreferenceKey {
    static let showFPSOverlay = "debug.showFPSOverlay"
}

enum FramePacingMeasurementControl {
    static let reset = Notification.Name("Trinket.FramePacing.Reset")
}

/// Corner frame-pacing readout for local diagnostics. Under XCTest it publishes only
/// a machine-readable accessibility node when explicitly enabled.
struct DebugFPSOverlayModifier: ViewModifier {
    @AppStorage(DebugPreferenceKey.showFPSOverlay) private var isEnabled = true

    private var enableFrameMetrics: Bool {
        AppEnvironment.shared.enableFrameMetrics
    }

    private var underXCTest: Bool {
        DebugRuntime.isUnderXCTest
    }

    private var runSampler: Bool {
        (isEnabled && !underXCTest) || enableFrameMetrics
    }

    private var showVisualBadge: Bool {
        isEnabled && !underXCTest
    }

    func body(content: Content) -> some View {
        content.overlay {
            if runSampler {
                FramePacingOverlayHost(showVisualBadge: showVisualBadge)
                    .allowsHitTesting(false)
            }
        }
    }
}

enum DebugRuntime {
    static var isUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

private struct FramePacingOverlayHost: View {
    let showVisualBadge: Bool

    @State private var report = FramePacingReport.empty
    @State private var monitor = FramePacingMonitor()

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showVisualBadge {
                FramePacingBadge(report: report)
                    .safeAreaPadding(.top, 4)
                    .safeAreaPadding(.leading, 6)
                    .accessibilityHidden(true)
            }

            Text(report.accessibilityValue)
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .accessibilityIdentifier(AccessibilityID.Debug.frameMetrics)
                .accessibilityValue(report.accessibilityValue)
                .accessibilityHidden(false)
                .frame(width: 1, height: 1)
                .accessibilityLabel("Frame Metrics")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            monitor.start { report = $0 }
        }
        .onReceive(NotificationCenter.default.publisher(for: FramePacingMeasurementControl.reset)) { _ in
            report = .empty
            monitor.resetMeasurement()
        }
        .onDisappear {
            monitor.stop()
        }
    }
}

private struct FramePacingBadge: View {
    let report: FramePacingReport

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "%.0f / %.0f FPS", report.averageFPS, report.expectedFPS))
                .font(.system(.caption2, design: .monospaced).weight(.bold))
            Text(String(
                format: "1%% %.1f · 0.1%% %.1f FPS",
                report.onePercentLowFPS,
                report.pointOnePercentLowFPS
            ))
            Text(String(format: "p95 %.1f · p99 %.1f · p999 %.1f ms", report.p95FrameMs, report.p99FrameMs, report.p999FrameMs))
                .font(.system(.caption2, design: .monospaced))
            if report.missedDeadlineCount > 0 || report.severeStallCount > 0 {
                Text(String(
                    format: "missed %d · severe %d",
                    report.missedDeadlineCount,
                    report.severeStallCount
                ))
                .font(.system(.caption2, design: .monospaced))
            }
        }
        .foregroundStyle(TrinketDesign.Colors.Overlay.paper)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule(style: .continuous)
                .fill(TrinketDesign.Colors.Overlay.ink.opacity(0.72))
        }
    }
}

@MainActor
private final class FramePacingMonitor: NSObject {
    private struct Sample: Sendable {
        let interval: CFTimeInterval
        let expectedFrameDuration: CFTimeInterval
    }

    /// Thirty seconds at 120 Hz; overwrites oldest samples without shifting an Array.
    private static let capacity = 3600
    private static let warmupSeconds: CFTimeInterval = 0.75
    /// Publishing every two seconds keeps the visual probe substantially below frame cadence.
    private static let publishInterval: CFTimeInterval = 2.0

    private var displayLink: CADisplayLink?
    private var previousTimestamp: CFTimeInterval = 0
    private var startTimestamp: CFTimeInterval = 0
    private var lastPublishTimestamp: CFTimeInterval = 0
    private var storage = [Sample?](repeating: nil, count: capacity)
    private var nextWriteIndex = 0
    private var sampleCount = 0
    private var analysisTask: Task<Void, Never>?
    private var handler: ((FramePacingReport) -> Void)?

    func start(onUpdate: @escaping (FramePacingReport) -> Void) {
        stop()
        handler = onUpdate
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func resetMeasurement() {
        analysisTask?.cancel()
        analysisTask = nil
        previousTimestamp = 0
        startTimestamp = 0
        lastPublishTimestamp = 0
        nextWriteIndex = 0
        sampleCount = 0
        storage = Array(repeating: nil, count: Self.capacity)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        handler = nil
        resetMeasurement()
    }

    @objc private func step(_ link: CADisplayLink) {
        let timestamp = link.timestamp
        if previousTimestamp == 0 {
            previousTimestamp = timestamp
            startTimestamp = timestamp
            lastPublishTimestamp = timestamp
            return
        }

        let interval = timestamp - previousTimestamp
        let expectedFrameDuration = link.targetTimestamp - link.timestamp
        previousTimestamp = timestamp
        guard interval > 0, interval.isFinite,
              expectedFrameDuration > 0, expectedFrameDuration.isFinite else { return }

        if timestamp - startTimestamp >= Self.warmupSeconds {
            storage[nextWriteIndex] = Sample(
                interval: interval,
                expectedFrameDuration: expectedFrameDuration
            )
            nextWriteIndex = (nextWriteIndex + 1) % Self.capacity
            sampleCount = min(sampleCount + 1, Self.capacity)
        }

        guard timestamp - lastPublishTimestamp >= Self.publishInterval else { return }
        lastPublishTimestamp = timestamp
        publishReport()
    }

    private func publishReport() {
        let samples: [Sample] = if sampleCount < Self.capacity {
            storage.prefix(sampleCount).compactMap(\.self)
        } else {
            (storage[nextWriteIndex...] + storage[..<nextWriteIndex]).compactMap(\.self)
        }
        guard !samples.isEmpty else { return }

        analysisTask?.cancel()
        let handler = handler
        analysisTask = Task {
            let report = await Task.detached(priority: .utility) {
                FramePacingAnalyzer.report(
                    intervals: samples.map(\.interval),
                    expectedFrameDurations: samples.map(\.expectedFrameDuration)
                )
            }.value
            guard !Task.isCancelled else { return }
            handler?(report)
        }
    }
}

extension View {
    func debugFPSOverlay() -> some View {
        modifier(DebugFPSOverlayModifier())
    }
}
#endif
