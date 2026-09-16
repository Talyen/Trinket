import QuartzCore
import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

#if DEBUG

struct DebugFPSOverlayModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

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
                        .onChange(of: scenePhase) { _, newPhase in
                            if newPhase == .active {
                                FramePacingMetricsProbe.shared.install()
                            }
                        }
                }
            }
    }
}

@MainActor
final class FramePacingMetricsProbe {
    static let shared = FramePacingMetricsProbe()

    private let monitor = FramePacingMonitor.measurementShared
    private var window: UIWindow?
    private var metricsLabel: UILabel?
    private var resetButton: UIButton?
    private var resetObserver: NSObjectProtocol?
    private var beginObserver: NSObjectProtocol?
    private var preparationTask: Task<Void, Never>?
    private var isInstalled = false
    // No deinit: this probe is a process-lifetime DEBUG singleton, so its two
    // NotificationCenter observers intentionally live until termination.

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
        metrics.accessibilityValue = "idle"
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
            reset.trailingAnchor.constraint(equalTo: root.view.safeAreaLayoutGuide.trailingAnchor, constant: -4),
            reset.bottomAnchor.constraint(equalTo: root.view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            reset.widthAnchor.constraint(equalToConstant: 44),
            reset.heightAnchor.constraint(equalToConstant: 44),
        ])
        window.rootViewController = root
        window.isHidden = false

        monitor.start { [weak self] report in
            self?.metricsLabel?.accessibilityValue = report.accessibilityValue
        }

        if ProcessInfo.processInfo.arguments.contains("-frame-metrics-launch") {
            metricsLabel?.accessibilityValue = "ready"
            beginMeasurement()
        }
        resetObserver = NotificationCenter.default.addObserver(
            forName: FramePacingMeasurementControl.reset, object: nil, queue: .main,
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.prepareMeasurement() }
        }
        beginObserver = NotificationCenter.default.addObserver(
            forName: FramePacingMeasurementControl.begin, object: nil, queue: .main,
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.beginMeasurement() }
        }
    }

    @objc private func handleResetTap() {
        switch metricsLabel?.accessibilityValue {
        case "ready": beginMeasurement()
        case "measuring": monitor.finishMeasurement()
        default: prepareMeasurement()
        }
    }

    private func prepareMeasurement() {
        preparationTask?.cancel()
        metricsLabel?.accessibilityValue = "preparing"
        monitor.resetMeasurement()
        preparationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(FramePacingMeasurementTiming.monitorWarmupSeconds))
            guard !Task.isCancelled else { return }
            metricsLabel?.accessibilityValue = "ready"
        }
    }

    private func beginMeasurement() {
        guard metricsLabel?.accessibilityValue == "ready" else { return }
        monitor.resetMeasurement()
        metricsLabel?.accessibilityValue = "measuring"
        monitor.scheduleSnapshot(after: .seconds(60))
        if ProcessInfo.processInfo.arguments.contains("-frame-metrics-validation-stall") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Deliberate diagnostic stimulus verifies that a main-thread stall reaches the report.
                Thread.sleep(forTimeInterval: 0.12)
            }
        }
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
    static let measurementShared = FramePacingMonitor()

    private var capture = FramePacingCapture()
    private var displayLink: CADisplayLink?
    private var finishRequested = false
    private var scheduledSnapshotTask: Task<Void, Never>?
    private var handler: ((FramePacingReport) -> Void)?

    func start(onUpdate: ((FramePacingReport) -> Void)? = nil) {
        if let onUpdate {
            handler = onUpdate
        }
        if displayLink != nil {
            return
        }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        // Stay paused until a measurement begins; an idle link would tax the
        // DEBUG runs this tool exists to measure. resetMeasurement unpauses.
        link.isPaused = true
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func resetMeasurement() {
        finishRequested = false
        scheduledSnapshotTask?.cancel()
        scheduledSnapshotTask = nil
        displayLink?.isPaused = false
        capture.begin(at: CACurrentMediaTime())
    }

    func finishMeasurement() {
        finishRequested = true
    }

    func snapshotMeasurement() {
        scheduledSnapshotTask?.cancel()
        scheduledSnapshotTask = nil
        displayLink?.isPaused = true
        handler?(capture.finish(at: CACurrentMediaTime()))
        NotificationCenter.default.post(name: FramePacingMeasurementControl.finished, object: nil)
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
        capture.record(at: link.timestamp, expectedDuration: link.targetTimestamp - link.timestamp)
        if finishRequested {
            finishRequested = false
            snapshotMeasurement()
        }
    }
}

extension View {
    func debugFPSOverlay() -> some View {
        modifier(DebugFPSOverlayModifier())
    }
}
#endif
