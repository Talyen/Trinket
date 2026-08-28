import TrinketContent

public extension MysteryEventPickContext {
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
