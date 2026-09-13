import CoreGraphics
import Foundation
import SwiftUI

public enum TrinketMotion: Sendable {
    public enum Interaction: Sendable {
        public static let artworkCardPressedScale: CGFloat = 0.99
        public static let walletIncreaseScale: CGFloat = 1.025
        public static let walletIncreaseDelayStep: TimeInterval = 0.055
        public static let walletIncreaseMaximumDelay: TimeInterval = 0.30
        public static let manaRestoreDuration: TimeInterval = 0.22
        public static let pendingIndicatorDelay: TimeInterval = 0.15
        public static let confirmationDuration: TimeInterval = 0.28

        public static let press: Animation = .spring(response: 0.18, dampingFraction: 1)

        public static let selection: Animation = .spring(response: 0.22, dampingFraction: 1)

        public static let stateChange: Animation = .easeOut(duration: 0.18)

        public static let progressArrival: Animation = .spring(response: 0.28, dampingFraction: 1)

        public static let walletIncrease: Animation = .spring(response: 0.35, dampingFraction: 1)
    }

    public enum Reward: Sendable {
        public static let collectionDuration: TimeInterval = 0.55
        public static let collectionLiftDuration: TimeInterval = 0.12
        public static let collectionWalletDelay: TimeInterval = 0.04
        public static let collectionLiftScale: CGFloat = 1.025
        public static let collectionGatherScale: CGFloat = 0.94
        public static let collectionLiftOffset: CGFloat = -4
        public static let collectionGatherOffset: CGFloat = 20
        public static let collectionLift: Animation = .easeOut(duration: collectionLiftDuration)
        public static let collectionGather: Animation = .easeIn(duration: 0.19)

        public static let resourceStagger: TimeInterval = 0.06
        public static let itemRevealDelay: TimeInterval = 0.08
        public static let completionDelay: TimeInterval = 0.10

        public static let stateChange: Animation = .spring(response: 0.22, dampingFraction: 1.0)

        public static let reveal: Animation = .spring(response: 0.28, dampingFraction: 0.88)
    }

    public enum Shine: Sendable {
        public static let loopPeriod: TimeInterval = 4.8

        static let textLoopPeriod: TimeInterval = 14.4

        @inlinable
        public static func phase(at elapsed: TimeInterval) -> Double {
            elapsed.truncatingRemainder(dividingBy: loopPeriod) / loopPeriod
        }
    }

    public enum Content: Sendable {
        public static let fadeDuration: TimeInterval = 0.20
        public static let entranceDuration: TimeInterval = 0.35
        public static let entranceStagger: TimeInterval = 0.08
        public static let secondEntranceDelay: TimeInterval = 0.16
        public static let cardDissolveDuration: TimeInterval = 1.0

        public static let fade: Animation = .easeOut(duration: fadeDuration)

        public static let entrance: Animation = .easeOut(duration: entranceDuration)
    }

    public enum Screen: Sendable {
        public static let crossfadeDuration: TimeInterval = 0.20

        public static let crossfade: Animation = .easeOut(duration: crossfadeDuration)
    }
}
