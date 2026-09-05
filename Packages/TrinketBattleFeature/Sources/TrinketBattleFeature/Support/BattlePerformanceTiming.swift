import Foundation
import TrinketFeatureSupport

public enum BattlePerformanceTiming {
    private static let quickMode =
        ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-battle-performance-quick")

    public static var isQuick: Bool {
        quickMode
    }

    public static var monitorWarmupSeconds: CFTimeInterval {
        isQuick ? 0.35 : 0.75
    }

    public static var harnessWarmup: Duration {
        isQuick ? .milliseconds(400) : .milliseconds(800)
    }

    public static var harnessMeasure: Duration {
        isQuick ? .seconds(2.5) : .seconds(6)
    }

    public static var snapshotDelay: Duration {
        isQuick ? .seconds(3.0) : .seconds(10)
    }
}
