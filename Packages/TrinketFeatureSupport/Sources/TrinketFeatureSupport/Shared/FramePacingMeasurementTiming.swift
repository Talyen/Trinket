import Foundation

public enum FramePacingMeasurementTiming {
    public static let isQuick =
        ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-battle-performance-quick")

    public static var monitorWarmupSeconds: TimeInterval {
        isQuick ? 0.35 : 0.75
    }

    public static var snapshotDelay: Duration {
        .seconds(snapshotSeconds)
    }

    public static var snapshotSeconds: TimeInterval {
        isQuick ? 3 : 10
    }
}
