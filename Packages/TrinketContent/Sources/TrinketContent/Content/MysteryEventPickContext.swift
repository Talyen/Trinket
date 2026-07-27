import Foundation

/// Context for weighted mystery event selection (Corruption Altar cadence).
public struct MysteryEventPickContext: Equatable, Sendable {
    public static let corruptionAltarReadyChancePercent = 25

    /// Journey chapter 2+ or Labyrinth.
    public var allowsCorruptionAltar: Bool
    public var hasEligibleCorruptTarget: Bool
    public var corruptionAltarCooldownRemaining: Int

    public init(
        allowsCorruptionAltar: Bool,
        hasEligibleCorruptTarget: Bool,
        corruptionAltarCooldownRemaining: Int
    ) {
        self.allowsCorruptionAltar = allowsCorruptionAltar
        self.hasEligibleCorruptTarget = hasEligibleCorruptTarget
        self.corruptionAltarCooldownRemaining = max(0, corruptionAltarCooldownRemaining)
    }

    public static let excludingCorruptionAltar = Self(
        allowsCorruptionAltar: false,
        hasEligibleCorruptTarget: false,
        corruptionAltarCooldownRemaining: 0
    )
}
