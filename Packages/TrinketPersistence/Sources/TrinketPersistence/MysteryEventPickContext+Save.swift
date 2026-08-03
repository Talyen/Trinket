import TrinketContent

public extension MysteryEventPickContext {
    /// Journey pick context: Corruption Altar from chapter 2+.
    static func journey(
        chapterNumber: Int,
        inventory: PlayerInventoryState,
        corruptionAltarCooldownRemaining: Int
    ) -> Self {
        Self(
            allowsCorruptionAltar: chapterNumber >= 2,
            hasEligibleCorruptTarget: !ItemCorruption.eligibleTargets(in: inventory).isEmpty,
            corruptionAltarCooldownRemaining: corruptionAltarCooldownRemaining
        )
    }

    /// Labyrinth pick context: Corruption Altar always chapter-eligible.
    static func labyrinth(
        inventory: PlayerInventoryState,
        corruptionAltarCooldownRemaining: Int
    ) -> Self {
        Self(
            allowsCorruptionAltar: true,
            hasEligibleCorruptTarget: !ItemCorruption.eligibleTargets(in: inventory).isEmpty,
            corruptionAltarCooldownRemaining: corruptionAltarCooldownRemaining
        )
    }
}
