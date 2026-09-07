import CoreGraphics
import Foundation
import SwiftUI

enum HomesteadMotion {
    static let depositGatherDuration = 0.09
    static let depositFlightDuration = 0.34
    static let depositStagger = 0.025
    static let depositSettle: Animation = .easeInOut(duration: 0.18)
    static let depositGather: Animation = .easeOut(duration: depositGatherDuration)
    static let depositFlight: Animation = .timingCurve(0.35, 0, 0.65, 1, duration: depositFlightDuration)

    static let celebrationPeak: CGFloat = 1.6
    static let celebrationRise = 0.12
    static let celebrationSettle = 0.38
}
