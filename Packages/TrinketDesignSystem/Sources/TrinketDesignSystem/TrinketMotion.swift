import CoreGraphics
import Foundation
import SwiftUI

public enum TrinketMotion: Sendable {
    public enum Interaction: Sendable {
        public static let artworkCardPressedScale: CGFloat = 0.99
        public static let choiceCardPressedScale: CGFloat = 0.975
        /// Surface press scale; intentionally subtler than card press.
        public static let surfacePressedScale: CGFloat = 0.98
        public static let walletIncreaseScale: CGFloat = 1.025
        public static let walletIncreaseDelayStep: TimeInterval = 0.055
        public static let walletIncreaseMaximumDelay: TimeInterval = 0.30
        public static let manaRestoreDuration: TimeInterval = 0.22
        public static let pendingIndicatorDelay: TimeInterval = 0.15
        public static let confirmationDuration: TimeInterval = 0.28

        public static let press: Animation = .spring(response: 0.18, dampingFraction: 1)

        public static let selection: Animation = .spring(response: 0.22, dampingFraction: 1)

        /// Generic state-transition ease. Distinct from
        /// `Reward.collectionStateChange`, which is a spring tuned for reward
        /// collection; keep the namespace.
        public static let stateChange: Animation = .easeOut(duration: 0.18)

        public static let progressArrival: Animation = .spring(response: 0.28, dampingFraction: 1)

        public static let walletIncrease: Animation = .spring(response: 0.35, dampingFraction: 1)

        /// Wallet bump entrance; the matching settle reuses `press`.
        public static let walletBump: Animation = .easeOut(duration: 0.08)
    }

    public enum Reward: Sendable {
        public static let categoryEntranceScale: CGFloat = 0.97
        /// Single stagger shared by category entrances and resource rows.
        /// Deliberately tighter than `Content.entranceStagger`: reward rows
        /// reveal in quick succession, content entrances breathe more.
        public static let entranceStagger: TimeInterval = 0.06
        public static let collectionDuration: TimeInterval = 0.35
        public static let collectionPulseScale: CGFloat = 1.025
        public static let cardCollectionPopScale: CGFloat = 1.05
        public static let collectionPulse: Animation = .easeInOut(duration: collectionDuration / 2)

        public static let entranceDelay: TimeInterval = 0.08
        public static let revealDuration: TimeInterval = 0.18

        /// Spring tuned for reward collection. Distinct from
        /// `Interaction.stateChange` (an easeOut for generic transitions).
        /// Named for its use (salvage/collection state flips), not its curve,
        /// so the two `stateChange` spellings never collide at call sites.
        public static let collectionStateChange: Animation = .spring(response: 0.22, dampingFraction: 1.0)

        public static let lootReveal: Animation = .easeOut(duration: revealDuration)

        public static let reveal: Animation = .spring(response: 0.28, dampingFraction: 0.88)
    }

    public enum Shine: Sendable {
        public static let loopPeriod: TimeInterval = 4.8

        public static let textLoopPeriod: TimeInterval = 14.4

        @inlinable
        public static func phase(at elapsed: TimeInterval, period: TimeInterval = loopPeriod) -> Double {
            elapsed.truncatingRemainder(dividingBy: period) / period
        }
    }

    public enum Content: Sendable {
        public static let fadeDuration: TimeInterval = 0.20
        public static let entranceDuration: TimeInterval = 0.35
        /// Looser than `Reward.entranceStagger` by intent; see that token.
        public static let entranceStagger: TimeInterval = 0.08
        public static let secondEntranceDelay: TimeInterval = entranceStagger * 2
        public static let cardDissolveDuration: TimeInterval = 1.0

        public static let fade: Animation = .easeOut(duration: fadeDuration)

        public static let entrance: Animation = .easeOut(duration: entranceDuration)
    }

    public enum Screen: Sendable {
        public static let crossfadeDuration: TimeInterval = 0.20

        public static let crossfade: Animation = .easeOut(duration: crossfadeDuration)
    }
}
