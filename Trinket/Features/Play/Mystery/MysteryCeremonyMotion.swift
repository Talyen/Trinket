import CoreGraphics
import Foundation
import SwiftUI

enum MysteryCeremonyMotion {
    static let veilHold: TimeInterval = 0.35
    static let unmaskResponse: TimeInterval = 0.48
    static let chromeAfterUnmask: TimeInterval = 0.12
    static let chromeStagger: TimeInterval = 0.10
    static let recruitButtonDelay: TimeInterval = 0.16
    static let sealResponse: TimeInterval = 0.32
    static let sealHoldBeforeDismiss: TimeInterval = 0.22
    static let sealArtPeakDelay: TimeInterval = 0.12
    static let bloomPeakOpacity = 0.40
    static let bloomPeakFraction = 0.40
    static let veiledBrightness = -0.18
    static let veiledOverlayOpacity = 0.55
    static let veiledArtScale: CGFloat = 0.97
    static let sealBadgeStartScale: CGFloat = 0.78
    static let sealArtPeakScale: CGFloat = 1.04

    static var unmask: Animation {
        .spring(response: unmaskResponse, dampingFraction: 0.92)
    }

    static var chrome: Animation {
        .spring(response: 0.36, dampingFraction: 0.95)
    }

    static var seal: Animation {
        .spring(response: sealResponse, dampingFraction: 0.82)
    }

    static var bloomIn: Animation {
        .easeOut(duration: unmaskResponse * bloomPeakFraction)
    }

    static var bloomOut: Animation {
        .easeOut(duration: unmaskResponse * (1 - bloomPeakFraction))
    }
}
