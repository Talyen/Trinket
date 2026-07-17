#if DEBUG
import QuartzCore
import SwiftUI
import TrinketDesignSystem
import UIKit

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

    private var showVisualBadge: Bool {
        isEnabled && !underXCTest
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if showVisualBadge {
                    FramePacingVisualBadgeHost()
                        .allowsHitTesting(false)
                }
            }
            .background {
                if enableFrameMetrics {
                    // UIWindow probe stays above Battle shell swaps and fullScreen covers
                    // so XCTest can always read a live accessibility value.
                    Color.clear
                        .frame(width: 0, height: 0)
                        .onAppear {
                            FramePacingMetricsProbe.shared.install()
                        }
                }
            }
    }
}

enum DebugRuntime {
    static var isUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

/// Human-facing badge only. Measurement probes live in `FramePacingMetricsProbe`.
///
/// Uses a process-wide display-link sampler and `.task` (not onAppear/stop) so the
/// launch warmup → ContentView shell swap cannot leave a visible badge with a
/// stopped CADisplayLink stuck at the empty report.
private struct FramePacingVisualBadgeHost: View {
    @State private var report = FramePacingReport.empty

    var body: some View {
        FramePacingBadge(report: report)
            .safeAreaPadding(.top, 4)
            .safeAreaPadding(.leading, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                let monitor = FramePacingMonitor.visualShared
                monitor.start(publishesAutomatically: true) { report = $0 }
                if monitor.latestReport.sampleCount > 0 {
                    report = monitor.latestReport
                }
                defer { monitor.detachHandler() }
                // Stay suspended until SwiftUI cancels this task on teardown.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60 * 60))
                }
            }
    }
}

/// Process-wide CADisplayLink + UIWindow accessibility probes for `-enable-frame-metrics`.
@MainActor
final class FramePacingMetricsProbe {
    static let shared = FramePacingMetricsProbe()

    /// Kept slightly inside the UI test's 7.2-second window so publication is
    /// complete before XCTest reads the frozen accessibility value.
    private static let measurementSnapshotDelay: Duration = .seconds(7)

    private let monitor = FramePacingMonitor.measurementShared
    private var window: UIWindow?
    private var metricsLabel: UILabel?
    private var resetButton: UIButton?
    private var resetObserver: NSObjectProtocol?
    private var isInstalled = false

    func install() {
        guard !isInstalled else {
            refreshWindowSceneIfNeeded()
            return
        }
        guard let window = makeWindow() else { return }
        isInstalled = true
        self.window = window

        let metrics = UILabel()
        metrics.isAccessibilityElement = true
        metrics.accessibilityIdentifier = AccessibilityID.Debug.frameMetrics
        metrics.accessibilityLabel = "Frame Metrics"
        metrics.accessibilityValue = FramePacingReport.empty.accessibilityValue
        metrics.text = " "
        metrics.font = .systemFont(ofSize: 1)
        metrics.textColor = .clear
        metrics.translatesAutoresizingMaskIntoConstraints = false
        metricsLabel = metrics

        let reset = UIButton(type: .system)
        reset.accessibilityIdentifier = AccessibilityID.Debug.frameMetricsReset
        reset.accessibilityLabel = "Frame Metrics Reset"
        reset.addTarget(self, action: #selector(handleResetTap), for: .touchUpInside)
        reset.translatesAutoresizingMaskIntoConstraints = false
        // Keep tappable for XCTest without stealing player hits.
        reset.backgroundColor = .clear
        resetButton = reset

        let root = UIViewController()
        root.view.backgroundColor = .clear
        root.view.addSubview(metrics)
        root.view.addSubview(reset)
        NSLayoutConstraint.activate([
            metrics.leadingAnchor.constraint(equalTo: root.view.leadingAnchor),
            metrics.topAnchor.constraint(equalTo: root.view.topAnchor),
            metrics.widthAnchor.constraint(equalToConstant: 1),
            metrics.heightAnchor.constraint(equalToConstant: 1),
            reset.centerXAnchor.constraint(equalTo: root.view.centerXAnchor),
            reset.topAnchor.constraint(equalTo: root.view.safeAreaLayoutGuide.topAnchor),
            reset.widthAnchor.constraint(equalToConstant: 44),
            reset.heightAnchor.constraint(equalToConstant: 44)
        ])
        window.rootViewController = root
        window.isHidden = false

        monitor.start(publishesAutomatically: true) { [weak self] report in
            self?.metricsLabel?.accessibilityValue = report.accessibilityValue
        }

        resetObserver = NotificationCenter.default.addObserver(
            forName: FramePacingMeasurementControl.reset,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resetMeasurement()
            }
        }
    }

    @objc private func handleResetTap() {
        resetMeasurement()
    }

    private func resetMeasurement() {
        metricsLabel?.accessibilityValue = FramePacingReport.empty.accessibilityValue
        monitor.resetMeasurement()
        monitor.scheduleSnapshot(after: Self.measurementSnapshotDelay)
    }

    private func makeWindow() -> PassThroughWindow? {
        guard let scene = activeWindowScene() else { return nil }
        let window = PassThroughWindow(windowScene: scene)
        // Above SwiftUI fullScreen covers / sheets; below system alerts.
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = true
        return window
    }

    private func refreshWindowSceneIfNeeded() {
        guard let window, window.windowScene == nil,
              let scene = activeWindowScene()
        else { return }
        window.windowScene = scene
    }

    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }
}

/// Forwards hits that miss the reset button so Battle/Mystery stay interactive.
private final class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        // Only the reset control should consume touches.
        if hit is UIControl {
            return hit
        }
        var view: UIView? = hit
        while let current = view {
            if current is UIControl {
                return hit
            }
            view = current.superview
        }
        return nil
    }
}

private struct FramePacingBadge: View {
    let report: FramePacingReport

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "%.0f FPS", report.averageFPS))
                .font(.system(.caption2, design: .monospaced).weight(.bold))
            Text(String(format: "1%% %.0f", report.onePercentLowFPS))
                .font(.system(.caption2, design: .monospaced))
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
final class FramePacingMonitor: NSObject {
    /// Survives ContentView shell swaps during `-enable-frame-metrics` UITests.
    static let measurementShared = FramePacingMonitor()
    /// Survives launch/shell remounts for the DEBUG FPS badge without stopping sampling.
    static let visualShared = FramePacingMonitor()

    private struct Sample: Sendable {
        let interval: CFTimeInterval
        let expectedFrameDuration: CFTimeInterval
    }

    /// Thirty seconds at 120 Hz; overwrites oldest samples without shifting an Array.
    private static let capacity = 3600
    private static let warmupSeconds: CFTimeInterval = 0.75
    /// Publishing every half-second keeps the badge responsive without matching frame cadence.
    private static let publishInterval: CFTimeInterval = 0.5

    private var displayLink: CADisplayLink?
    private var previousTimestamp: CFTimeInterval = 0
    private var startTimestamp: CFTimeInterval = 0
    private var lastPublishTimestamp: CFTimeInterval = 0
    private var storage = [Sample?](repeating: nil, count: capacity)
    private var nextWriteIndex = 0
    private var sampleCount = 0
    private var analysisTask: Task<Void, Never>?
    private var scheduledSnapshotTask: Task<Void, Never>?
    private var handler: ((FramePacingReport) -> Void)?
    private var publishesAutomatically = true
    private(set) var latestReport = FramePacingReport.empty

    func start(
        publishesAutomatically: Bool = true,
        onUpdate: @escaping (FramePacingReport) -> Void
    ) {
        handler = onUpdate
        self.publishesAutomatically = publishesAutomatically
        if let displayLink {
            // Drop the pause gap so the next tick re-seeds interval baselines.
            previousTimestamp = 0
            displayLink.isPaused = false
            return
        }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func detachHandler() {
        handler = nil
        // Pause while no subscriber is attached; start() unpauses on re-subscribe.
        displayLink?.isPaused = true
    }

    func resetMeasurement() {
        analysisTask?.cancel()
        analysisTask = nil
        scheduledSnapshotTask?.cancel()
        scheduledSnapshotTask = nil
        displayLink?.isPaused = false
        previousTimestamp = 0
        startTimestamp = 0
        lastPublishTimestamp = 0
        nextWriteIndex = 0
        sampleCount = 0
        storage = Array(repeating: nil, count: Self.capacity)
        latestReport = .empty
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        handler = nil
        resetMeasurement()
    }

    /// Freezes collection before reporting so the diagnostic publication cannot
    /// contaminate the interval set it is reporting.
    func snapshotMeasurement() {
        displayLink?.isPaused = true
        // Publish synchronously so XCTest can read the accessibility value
        // without racing the detached analysis Task.
        publishReport(synchronously: true)
    }

    func scheduleSnapshot(after delay: Duration) {
        scheduledSnapshotTask?.cancel()
        scheduledSnapshotTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            snapshotMeasurement()
            scheduledSnapshotTask = nil
        }
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

        guard publishesAutomatically,
              timestamp - lastPublishTimestamp >= Self.publishInterval else { return }
        lastPublishTimestamp = timestamp
        // Publish on the display-link turn. Percentile work over the ring buffer is
        // cheap; avoiding Task.detached prevents cancel/resume races from dropping
        // every update and leaving the badge stuck at the empty report.
        publishReport(synchronously: true)
    }

    private func publishReport(synchronously: Bool) {
        let samples: [Sample] = if sampleCount < Self.capacity {
            storage.prefix(sampleCount).compactMap(\.self)
        } else {
            (storage[nextWriteIndex...] + storage[..<nextWriteIndex]).compactMap(\.self)
        }
        guard !samples.isEmpty else { return }
        analysisTask?.cancel()

        let intervals = samples.map(\.interval)
        let expectedDurations = samples.map(\.expectedFrameDuration)

        if synchronously {
            let built = FramePacingAnalyzer.report(
                intervals: intervals,
                expectedFrameDurations: expectedDurations
            )
            latestReport = built
            handler?(built)
            return
        }

        let capturedHandler = handler
        // Concurrency-Safety: outer Task stays on @MainActor for handler delivery;
        // Task.detached runs pure percentile analysis off the display-link actor.
        analysisTask = Task { @MainActor in
            let built = await Task.detached(priority: .utility) {
                FramePacingAnalyzer.report(
                    intervals: intervals,
                    expectedFrameDurations: expectedDurations
                )
            }.value
            guard !Task.isCancelled else { return }
            latestReport = built
            capturedHandler?(built)
        }
    }
}

extension View {
    func debugFPSOverlay() -> some View {
        modifier(DebugFPSOverlayModifier())
    }
}
#endif
