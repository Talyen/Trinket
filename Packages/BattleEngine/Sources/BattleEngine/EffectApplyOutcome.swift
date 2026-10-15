package struct EffectApplyOutcome {
    package var didApply: Bool = true
    /// Direct grants exclude any gains produced by nested reactions.
    package var grantedGold: Int = 0
    package var restoredMana: Int = 0
    package var criticalAttackActorIDs: Set<String> = []
}
