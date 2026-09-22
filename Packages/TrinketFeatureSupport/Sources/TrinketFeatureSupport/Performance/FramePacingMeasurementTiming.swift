import Foundation

public enum FramePacingMeasurementTiming {
    public static let isQuick =
        ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-battle-performance-quick")

    public static var monitorWarmupSeconds: TimeInterval {
        isQuick ? 0.35 : 0.75
    }
}

public enum FramePacingMeasurementControl {
    public static let reset = Notification.Name("Trinket.FramePacing.Reset")
    public static let finished = Notification.Name("Trinket.FramePacing.Finished")
    public static let begin = Notification.Name("Trinket.FramePacing.Begin")
}
