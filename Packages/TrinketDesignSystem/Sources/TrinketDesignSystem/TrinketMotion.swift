import CoreGraphics
import Foundation
import SwiftUI

/// Motion shared by multiple product features.
public enum TrinketMotion: Sendable {
    /// Restrained feedback for ordinary controls and committed state changes.
    public enum Interaction: Sendable {
        public static let artworkCardPressedScale: CGFloat = 0.99
        public static let selectionCardPressedScale: CGFloat = 0.995
        public static let walletIncreaseScale: CGFloat = 1.025
        public static let walletIncreaseDelayStep: TimeInterval = 0.055
        public static let walletIncreaseMaximumDelay: TimeInterval = 0.30
        public static let manaSpendDuration: TimeInterval = 0.16
        public static let manaRestoreDuration: TimeInterval = 0.22

        public static var press: Animation {
            .spring(response: 0.18, dampingFraction: 1)
        }

        public static var selection: Animation {
            .spring(response: 0.22, dampingFraction: 1)
        }

        public static var stateChange: Animation {
            .easeOut(duration: 0.18)
        }

        public static var progressArrival: Animation {
            .spring(response: 0.28, dampingFraction: 1)
        }

        public static var walletIncrease: Animation {
            .spring(response: 0.35, dampingFraction: 1)
        }
    }

    public enum Reward: Sendable {
        public static let resourceStagger: TimeInterval = 0.06
        public static let itemRevealDelay: TimeInterval = 0.08
        public static let completionDelay: TimeInterval = 0.10

        public static var stateChange: Animation {
            .spring(response: 0.22, dampingFraction: 1.0)
        }

        public static var reveal: Animation {
            .spring(response: 0.28, dampingFraction: 0.88)
        }
    }

    /// Traveling keyword-affinity shine.
    public enum Shine: Sendable {
        /// One full loop shared by text and border shine.
        public static let loopPeriod: TimeInterval = 4.8
        /// Loop period for fast text gradient sweeps.
        public static let textShineDuration: TimeInterval = 2.4

        public static var textAnimation: Animation {
            .linear(duration: textShineDuration).repeatForever(autoreverses: false)
        }

        /// Normalized position within the shared loop for a nonnegative clock value.
        @inlinable
        public static func phase(at elapsed: TimeInterval) -> Double {
            elapsed.truncatingRemainder(dividingBy: loopPeriod) / loopPeriod
        }
    }

    /// Shared fades and staged entrances for ordinary screen content.
    public enum Content: Sendable {
        public static let fadeDuration: TimeInterval = 0.20
        public static let entranceDuration: TimeInterval = 0.35
        public static let entranceStagger: TimeInterval = 0.08
        public static let secondEntranceDelay: TimeInterval = 0.16
        public static let cardDissolveDuration: TimeInterval = 1.0

        public static var fade: Animation {
            .easeOut(duration: fadeDuration)
        }

        public static var entrance: Animation {
            .easeOut(duration: entranceDuration)
        }
    }

    /// Short opacity crossfades for full-screen content swaps (battle shell, outcomes).
    public enum Screen: Sendable {
        public static let crossfadeDuration: TimeInterval = 0.20

        public static var crossfade: Animation {
            .easeOut(duration: crossfadeDuration)
        }
    }
}
