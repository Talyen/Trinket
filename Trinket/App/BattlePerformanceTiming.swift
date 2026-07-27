import Foundation

/// Shared wall-clock knobs for Battle performance harness + UITest waits.
/// Set `TRINKET_PERFORMANCE_QUICK=1` (via `test.sh` → `TEST_RUNNER_…`) for fast isolation.
/// Launch arg `-battle-performance-quick` is the app-side fallback when env is not forwarded.
enum BattlePerformanceTiming {
    static var isQuick: Bool {
        ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-battle-performance-quick")
    }

    /// Display-link discard after reset before samples count toward the report.
    static var monitorWarmupSeconds: CFTimeInterval {
        isQuick ? 0.35 : 0.75
    }

    /// Harness delay after reset before stimulus (must be ≥ monitor warmup).
    static var harnessWarmup: Duration {
        isQuick ? .milliseconds(400) : .milliseconds(800)
    }

    /// How long samples accumulate after stimulus begins.
    static var harnessMeasure: Duration {
        isQuick ? .seconds(2.5) : .seconds(6)
    }

    /// When the metrics probe freezes the accessibility report.
    /// Full window must leave enough post-warmup samples under CI simulator load
    /// (often well below 60 Hz) to satisfy the XCTest capture threshold.
    static var snapshotDelay: Duration {
        isQuick ? .seconds(3.0) : .seconds(10)
    }
}
