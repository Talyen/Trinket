import Foundation
import MetricKit
import os
import TrinketPersistence

struct MetricKitDiagnosticSnapshot: Sendable {
    enum Kind: Sendable {
        case crash(signal: Int?, terminationReason: String?)
        case hang(durationSeconds: Double)
        case diskWrite(totalMegabytes: Double)
    }

    let kind: Kind
    let applicationVersion: String
    let periodStart: TimeInterval
    let periodEnd: TimeInterval
}

@MainActor
final class MetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricKitSubscriber()

    private let logger = Logger(subsystem: PlayerSaveDefaults.loggingSubsystem, category: "MetricKit")
    private var isSubscribed = false

    func start() {
        guard !isSubscribed else { return }
        MXMetricManager.shared.add(self)
        isSubscribed = true
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        // Collect first so the MainActor hop happens once per batch, not once
        // per payload; MetricKit delivers these off the main thread.
        let hitchRatios = payloads.compactMap { $0.animationMetrics?.hitchTimeRatio }
        guard !hitchRatios.isEmpty else { return }
        Task { @MainActor in
            for hitchRatio in hitchRatios {
                self.logger.info(
                    "MXAnimationMetric hitchTimeRatio=\(String(describing: hitchRatio), privacy: .public)",
                )
            }
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let snapshots = payloads.flatMap(Self.snapshots)
        guard !snapshots.isEmpty else { return }
        Task { @MainActor in
            for snapshot in snapshots {
                self.log(snapshot)
            }
        }
    }

    nonisolated static func snapshots(
        for payload: MXDiagnosticPayload,
    ) -> [MetricKitDiagnosticSnapshot] {
        let periodStart = payload.timeStampBegin.timeIntervalSince1970
        let periodEnd = payload.timeStampEnd.timeIntervalSince1970

        var snapshots: [MetricKitDiagnosticSnapshot] = []
        for diagnostic in payload.crashDiagnostics ?? [] {
            snapshots.append(MetricKitDiagnosticSnapshot(
                kind: .crash(
                    signal: diagnostic.signal?.intValue,
                    terminationReason: diagnostic.terminationReason,
                ),
                applicationVersion: diagnostic.applicationVersion,
                periodStart: periodStart,
                periodEnd: periodEnd,
            ))
        }
        for diagnostic in payload.hangDiagnostics ?? [] {
            snapshots.append(MetricKitDiagnosticSnapshot(
                kind: .hang(
                    durationSeconds: diagnostic.hangDuration.converted(to: .seconds).value,
                ),
                applicationVersion: diagnostic.applicationVersion,
                periodStart: periodStart,
                periodEnd: periodEnd,
            ))
        }
        for diagnostic in payload.diskWriteExceptionDiagnostics ?? [] {
            snapshots.append(MetricKitDiagnosticSnapshot(
                kind: .diskWrite(
                    totalMegabytes: diagnostic.totalWritesCaused.converted(to: .megabytes).value,
                ),
                applicationVersion: diagnostic.applicationVersion,
                periodStart: periodStart,
                periodEnd: periodEnd,
            ))
        }
        return snapshots
    }

    private func log(_ snapshot: MetricKitDiagnosticSnapshot) {
        switch snapshot.kind {
        case let .crash(signal, terminationReason):
            logger.fault(
                """
                crash appVersion=\(snapshot.applicationVersion, privacy: .public) \
                periodStart=\(snapshot.periodStart, privacy: .public) \
                periodEnd=\(snapshot.periodEnd, privacy: .public) \
                signal=\(signal.map { String($0) } ?? "unknown", privacy: .public) \
                terminationReason=\(terminationReason ?? "unknown", privacy: .private)
                """,
            )
        case let .hang(durationSeconds):
            logger.error(
                """
                hang appVersion=\(snapshot.applicationVersion, privacy: .public) \
                periodStart=\(snapshot.periodStart, privacy: .public) \
                periodEnd=\(snapshot.periodEnd, privacy: .public) \
                durationSeconds=\(durationSeconds, privacy: .public)
                """,
            )
        case let .diskWrite(totalMegabytes):
            logger.error(
                """
                diskWrite appVersion=\(snapshot.applicationVersion, privacy: .public) \
                periodStart=\(snapshot.periodStart, privacy: .public) \
                periodEnd=\(snapshot.periodEnd, privacy: .public) \
                totalMegabytes=\(totalMegabytes, privacy: .public)
                """,
            )
        }
    }
}
