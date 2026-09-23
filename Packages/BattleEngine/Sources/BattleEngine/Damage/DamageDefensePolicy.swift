import TrinketContent
import TrinketCore

enum DamageDefensePolicy {
    static func cappedDamage(_ amount: Int, operation: DamageOperation, cap: Int) -> Int {
        cap > 0 && !operation.isHealthCost ? min(amount, cap) : amount
    }

    private static func clamped01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    static func mitigationMultiplier(state: DamageResolutionState, context: BattleState) -> Double {
        guard let sourceActorID = state.sourceActorID else { return 1 }
        let sourceProfile = context.modifiers(for: sourceActorID)
        // Full-mitigation bypasses: each keyword owns its own trigger flag.
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
        if state.damageKeyword == .physical {
            let physical = max(
                sourceProfile.triggers.physicalIgnoreMitigationPercent,
                sourceProfile.triggers.ignoreEnemyMitigationPercent,
            )
            return 1 - clamped01(physical)
        }
        return 1 - clamped01(sourceProfile.triggers.ignoreEnemyMitigationPercent)
    }

    static func blockMultiplier(state: DamageResolutionState, in context: BattleState) -> Double {
        let blindSpot = state.options.isCardAttack && state.damageKeyword == .physical
            && context.resolution.cardTalents?.actorID == state.sourceActorID
            && context.resolution.cardTalents?.preparations.contains(.ignorePhysicalBlock) == true
        if blindSpot || UniqueCombatEngine.ignoresBlock(for: state, in: context) {
            return 0
        }
        guard let sourceID = state.sourceActorID else { return 1 }
        let triggers = context.modifiers(for: sourceID).triggers
        if state.damageKeyword == .burn, state.combatant.role == .enemy, triggers.burnIgnoresBlock {
            return 0
        }
        if state.damageKeyword == .poison, state.options.isAttackHit,
           state.combatant.role == .enemy, triggers.rootPassage {
            return 0
        }
        if keywordIgnoresBlock(keyword: state.damageKeyword, sourceTriggers: triggers, sourceActorID: sourceID, in: context) {
            return 0
        }
        if state.damageKeyword == .bleed, state.combatant.role == .enemy, triggers.bleedIgnoresEnemyBlock {
            return 0
        }
        if state.damageKeyword == .physical, state.isCritical,
           state.combatant.role == .enemy, triggers.cleanCut {
            return 0
        }
        var ignored = 0.0
        if state.combatant.role == .enemy {
            if state.damageKeyword == .holy {
                ignored = max(ignored, triggers.holyBlockIgnorePercent)
            }
            if state.damageKeyword == .bleed, state.options.isAttackHit {
                ignored = max(ignored, triggers.bleedAttackBlockIgnorePercent)
            }
            if state.options.isAttackHit, state.options.abilityHasLeech {
                ignored = max(ignored, triggers.leechAttackBlockIgnorePercent)
            }
        }
        if state.damageKeyword == .physical {
            if triggers.physicalIgnoresBlockVsStunnedOrFrozen, state.targetStatus.isStunned || state.targetStatus.isFrozen {
                return 0
            }
            ignored = max(ignored, triggers.physicalBlockIgnorePercent)
        }
        return 1 - clamped01(ignored)
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
