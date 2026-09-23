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
        if state.ignoreBlockFromTalent {
            return 0
        }
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
        if keywordIgnoresBlock(keyword: state.damageKeyword, sourceTriggers: triggers) {
            return 0
        }
        if state.damageKeyword == .bleed, state.combatant.role == .enemy, triggers.bleedIgnoresEnemyBlock {
            return 0
        }
        if talentAttackIgnoresBlock(state: state, triggers: triggers, sourceID: sourceID, in: context) {
            return 0
        }
        var ignored = 0.0
        if state.combatant.role == .enemy {
            if state.damageKeyword == .holy, state.options.isAttackHit {
                ignored = max(ignored, triggers.holyBlockIgnorePercent)
            }
            if state.damageKeyword == .bleed, state.options.isAttackHit {
                ignored = max(ignored, triggers.bleedAttackBlockIgnorePercent)
            }
            if state.damageKeyword == .stun, state.options.isAttackHit {
                ignored = max(ignored, triggers.stunBlockIgnorePercent)
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

    private static func talentAttackIgnoresBlock(
        state: DamageResolutionState,
        triggers: CombatTraitTriggers,
        sourceID: String,
        in context: BattleState,
    ) -> Bool {
        guard state.combatant.role == .enemy else { return false }
        if state.damageKeyword == .physical, state.isCritical, triggers.cleanCut {
            return true
        }
        if state.damageKeyword == .holy, state.options.isAttackHit, triggers.unbrokenVow,
           let source = context.roster.combatant(for: sourceID),
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source.combatant)) > 0 {
            return true
        }
        guard state.options.isAttackHit, state.isCritical else { return false }
        return state.damageKeyword == .burn && triggers.burnCriticalIgnoreBlock
            || state.damageKeyword == .stun && triggers.stunCriticalIgnoreBlock
    }

    private static func keywordIgnoresBlock(
        keyword: Keyword?,
        sourceTriggers: CombatTraitTriggers,
    ) -> Bool {
        guard let keyword else { return false }
        if keyword == .freeze, sourceTriggers.ghostfrost {
            return true
        }
        if keyword == .holy {
            if sourceTriggers.holyIgnoresBlock || sourceTriggers.holyIgnoresBlockAndDodge {
                return true
            }
        }
        if keyword == .burn, sourceTriggers.burnIgnoresBlockAndMitigation {
            return true
        }
        return false
    }
}
