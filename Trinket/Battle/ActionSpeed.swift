import Foundation

struct ActionSpeed: Hashable {
    var baseIntervalTicks: Int
    var intervalModifier: Int = 0

    var effectiveInterval: Int {
        max(1, baseIntervalTicks + intervalModifier)
    }
}
