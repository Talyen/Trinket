import CoreGraphics
import Foundation
import SwiftUI

enum HomesteadMotion {
    static let readyLift: CGFloat = 4
    static let readyRiseDuration = 0.18
    static let readyReturnDuration = 0.3
    static let readyStagger = 0.1
    static let readyRestDuration = 3.0

    static let depositGatherDuration = 0.09
    static let depositFlightDuration = 0.34
    static let depositStagger = 0.025
    static let depositSettle: Animation = .easeInOut(duration: 0.18)
    static let depositGather: Animation = .easeOut(duration: depositGatherDuration)
    static let depositFlight: Animation = .timingCurve(0.35, 0, 0.65, 1, duration: depositFlightDuration)

    static let segmentDuration = 0.5
    static let valueHighlightDuration = 0.55
    static let valueReveal: Animation = .smooth(duration: 0.32)
    static let valueSettle: Animation = .easeOut(duration: 0.25)
    static let celebrationPeak: CGFloat = 2.4
    static let celebrationRise = 0.12
    static let celebrationSettle = 0.38
}
