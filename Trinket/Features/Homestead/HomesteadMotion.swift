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

    static var tierCompletion: Animation {
        .spring(response: 0.35, dampingFraction: 1)
    }

    static let connectorFillDuration: TimeInterval = 0.20
    static let connectorFillStagger: TimeInterval = 0.08

    static var connectorFill: Animation {
        .easeOut(duration: connectorFillDuration)
    }

    static var nodeSettleDelay: TimeInterval {
        connectorFillDuration
    }

    static var nodeSettle: Animation {
        .spring(response: 0.32, dampingFraction: 0.85)
    }

    static let nodeSettlePeakScale: CGFloat = 1.06
}
