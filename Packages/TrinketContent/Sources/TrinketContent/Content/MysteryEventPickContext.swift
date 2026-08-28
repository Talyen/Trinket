import Foundation

public struct MysteryEventPickContext: Equatable, Sendable {
    public static let corruptionAltarReadyChancePercent = 25

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
