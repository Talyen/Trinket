import CoreGraphics
import Foundation
import SwiftUI

enum HomesteadMotion {
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
