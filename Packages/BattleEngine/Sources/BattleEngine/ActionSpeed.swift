import Foundation
import TrinketCore
import TrinketContent

public struct ActionSpeed: Hashable {
    public var baseIntervalTicks: Int
    public var intervalModifier: Int = 0

    public var effectiveInterval: Int {
        max(1, baseIntervalTicks + intervalModifier)
    }
}
