import Foundation
import MetricKit
import os

/// Production hitch-time-ratio trends via MetricKit. Complements the local
/// Simulator matrix; does not replace reproducible scenario reports.
@MainActor
final class MetricKitHitchSubscriber: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricKitHitchSubscriber()

    private let log = Logger(subsystem: "com.trinket.framepacing", category: "MetricKit")
    private var isSubscribed = false

    func start() {
        guard !isSubscribed else { return }
        MXMetricManager.shared.add(self)
        isSubscribed = true
    }

    func stop() {
        guard isSubscribed else { return }
        MXMetricManager.shared.remove(self)
        isSubscribed = false
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            guard let animation = payload.animationMetrics else { continue }
            let hitchRatio = animation.hitchTimeRatio
            Task { @MainActor in
                self.log.info(
                    "MXAnimationMetric hitchTimeRatio=\(String(describing: hitchRatio), privacy: .public)"
                )
            }
        }
    }
}
