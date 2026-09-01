import QuartzCore
import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

#if DEBUG

struct DebugFPSOverlayModifier: ViewModifier {
    private var enableFrameMetrics: Bool {
        AppEnvironment.shared.enableFrameMetrics
    }

    func body(content: Content) -> some View {
        content
            .background {
                if enableFrameMetrics {
                    Color.clear
                        .frame(width: 0, height: 0)
                        .onAppear {
                            FramePacingMetricsProbe.shared.install()
                        }
                }
            }
    }
}

@MainActor
final class FramePacingMetricsProbe {
    static let shared = FramePacingMetricsProbe()

    private static var measurementSnapshotDelay: Duration {
        BattlePerformanceTiming.snapshotDelay
    }

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
            reset.heightAnchor.constraint(equalToConstant: 44),
        ])
        window.rootViewController = root
        window.isHidden = false

        monitor.start { [weak self] report in
            self?.metricsLabel?.accessibilityValue = report.accessibilityValue
        }

        resetObserver = NotificationCenter.default.addObserver(
            forName: FramePacingMeasurementControl.reset,
            object: nil,
            queue: .main,
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

private final class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
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

@MainActor
final class FramePacingMonitor: NSObject {
    static let measurementShared = FramePacingMonitor(windowSeconds: 30)

    private struct Sample {
        let interval: CFTimeInterval
        let expectedFrameDuration: CFTimeInterval
    }

    private static let maxRefreshRate: CFTimeInterval = 120
    private static var warmupSeconds: CFTimeInterval {
        BattlePerformanceTiming.monitorWarmupSeconds
    }

    private let windowSeconds: CFTimeInterval
    private let capacity: Int
    private var displayLink: CADisplayLink?
    private var previousTimestamp: CFTimeInterval = 0
    private var startTimestamp: CFTimeInterval = 0
    private var storage: [Sample?]
    private var nextWriteIndex = 0
    private var sampleCount = 0
    private var scheduledSnapshotTask: Task<Void, Never>?
    private var handler: ((FramePacingReport) -> Void)?

    private init(windowSeconds: CFTimeInterval) {
        self.windowSeconds = windowSeconds
        capacity = max(1, Int((windowSeconds * Self.maxRefreshRate).rounded(.up)))
        storage = Array(repeating: nil, count: capacity)
    }

    func start(onUpdate: ((FramePacingReport) -> Void)? = nil) {
        if let onUpdate {
            handler = onUpdate
        }
        if let displayLink {
            previousTimestamp = 0
            displayLink.isPaused = false
            return
        }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func resetMeasurement() {
        scheduledSnapshotTask?.cancel()
        scheduledSnapshotTask = nil
        displayLink?.isPaused = false
        previousTimestamp = 0
        startTimestamp = 0
        nextWriteIndex = 0
        sampleCount = 0
        storage = Array(repeating: nil, count: capacity)
    }

    func snapshotMeasurement() {
        displayLink?.isPaused = true
        let ordered: [Sample] = if sampleCount < capacity {
            storage.prefix(sampleCount).compactMap(\.self)
        } else {
            (storage[nextWriteIndex...] + storage[..<nextWriteIndex]).compactMap(\.self)
        }
        let samples = Self.samples(inLast: windowSeconds, from: ordered)
        let report = if samples.isEmpty {
            FramePacingReport.empty
        } else {
            FramePacingAnalyzer.report(
                intervals: samples.map(\.interval),
                expectedFrameDurations: samples.map(\.expectedFrameDuration),
            )
        }
        handler?(report)
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
                expectedFrameDuration: expectedFrameDuration,
            )
            nextWriteIndex = (nextWriteIndex + 1) % capacity
            sampleCount = min(sampleCount + 1, capacity)
        }
    }

    private static func samples(inLast windowSeconds: CFTimeInterval, from ordered: [Sample]) -> [Sample] {
        guard windowSeconds > 0, !ordered.isEmpty else { return ordered }
        var total: CFTimeInterval = 0
        var count = 0
        for sample in ordered.reversed() {
            total += sample.interval
            count += 1
            if total >= windowSeconds {
                break
            }
        }
        return Array(ordered.suffix(count))
    }
}

extension View {
    func debugFPSOverlay() -> some View {
        modifier(DebugFPSOverlayModifier())
    }
}
#endif
