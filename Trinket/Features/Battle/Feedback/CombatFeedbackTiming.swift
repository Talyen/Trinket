import Foundation
import TrinketDesignSystem

/// Compatibility aliases for combat feedback timing. Prefer `TrinketMotion.Battle` recipes.
enum CombatFeedbackTiming {
    static let displayDuration: TimeInterval = TrinketMotion.Battle.chipDisplayDuration
    static let reduceMotionFadeIn: TimeInterval = TrinketMotion.Battle.reduceMotionChipFadeIn
    static let reduceMotionHold: TimeInterval = TrinketMotion.Battle.reduceMotionChipHold
    static let reduceMotionFadeOut: TimeInterval = TrinketMotion.Battle.reduceMotionChipFadeOut
    static let stackSpacing: CGFloat = 22
    static let ultimateChipStagger: TimeInterval = TrinketMotion.Battle.ultimateChipStagger
}
