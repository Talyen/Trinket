import TrinketContent
import TrinketCore

enum DamageDefensePolicy {
    static func cappedDamage(_ amount: Int, operation: DamageOperation, cap: Int) -> Int {
        cap > 0 && !operation.isHealthCost ? min(amount, cap) : amount
    }

    static func mitigationMultiplier(state: DamageResolutionState, context: BattleState) -> Double {
        guard let sourceActorID = state.sourceActorID else { return 1 }
        let sourceProfile = context.modifiers(for: sourceActorID)
        if state.options.abilityHasLeech, sourceProfile.triggers.leechIgnoresMitigation {
            return 0
        }
        if state.damageKeyword == .burn, sourceProfile.triggers.burnIgnoresBlockAndMitigation {
            return 0
        }
        if state.damageKeyword == .bleed, sourceProfile.triggers.bleedsIgnoreMitigation {
            return 0
        }
        guard state.combatant.role == .enemy else { return 1 }
        return 1 - min(1, max(0, sourceProfile.triggers.ignoreEnemyMitigationPercent))
    }

    static func blockMultiplier(state: DamageResolutionState, in context: BattleState) -> Double {
        let blindSpot = state.options.isOriginalCardDamage && state.damageKeyword == .physical
            && context.resolution.cardTalents?.actorID == state.sourceActorID
            && context.resolution.cardTalents?.preparations.contains(.ignorePhysicalBlock) == true
        if blindSpot || UniqueCombatEngine.ignoresBlock(for: state, in: context) {
            return 0
        }
        guard let sourceID = state.sourceActorID else { return 1 }
        let triggers = context.modifiers(for: sourceID).triggers
        if keywordIgnoresBlock(keyword: state.damageKeyword, sourceTriggers: triggers, sourceActorID: sourceID, in: context) {
            return 0
        }
        guard state.damageKeyword == .physical else { return 1 }
        if triggers.physicalIgnoresBlockVsStunnedOrFrozen, state.targetStatus.isStunned || state.targetStatus.isFrozen {
            return 0
        }
        return 1 - min(1, max(0, triggers.physicalBlockIgnorePercent))
    }

    private static func keywordIgnoresBlock(
        keyword: Keyword?,
        sourceTriggers: CombatTraitTriggers,
        sourceActorID: String?,
        in context: BattleState,
    ) -> Bool {
        guard let keyword else { return false }
        if keyword == .freeze, sourceTriggers.ghostfrost {
            return true
        }
        if keyword == .holy {
            if sourceTriggers.holyIgnoresBlock || sourceTriggers.holyIgnoresBlockAndDodge {
                return true
            }
            if let sourceActorID,
               let src = context.roster.combatant(for: sourceActorID) {
                let partyUnbroken = (src.role != .enemy) && CombatTriggerEngine.hasLivingPartyTrigger(\.unbrokenVow, in: context)
                if sourceTriggers.unbrokenVow || partyUnbroken,
                   DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: src.combatant)) > 0 {
                    return true
                }
            }
        }
        if keyword == .burn, sourceTriggers.burnIgnoresBlockAndMitigation {
            return true
        }
        return false
    }
}
