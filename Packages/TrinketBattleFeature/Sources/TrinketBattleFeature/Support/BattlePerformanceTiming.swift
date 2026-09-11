import Foundation
import TrinketFeatureSupport

enum BattlePerformanceTiming {
    static var harnessWarmup: Duration {
        FramePacingMeasurementTiming.isQuick ? .milliseconds(400) : .milliseconds(800)
    }

    static var harnessMeasure: Duration {
        FramePacingMeasurementTiming.isQuick ? .seconds(2.5) : .seconds(6)
    }
}
