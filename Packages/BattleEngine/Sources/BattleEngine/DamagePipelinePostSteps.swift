import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyLeech(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.healthLost > 0,
              let sourceActorID = state.sourceActorID,
              sourceActorID != state.combatant.id
        else { return }
        let leechOutcome = HealingEngine.leechFromDamage(
            state.healthLost,
            sourceActorID: sourceActorID,
            target: state.combatant,
            blockedAmount: state.blockedAmount,
            abilityHasLeech: state.options.abilityHasLeech,
            damageKeyword: state.damageKeyword,
            in: &context,
        )
        state.damageEvents.append(contentsOf: leechOutcome.events)
    }

    static func applyKeywordReactions(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.healthLost > 0,
              let keyword = state.damageKeyword,
              let source = state.partySource(in: context)
        else { return }

        switch keyword {
        case .holy:
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterHolyDamageDealt(
                to: state.combatant,
                source: source.combatant,
                isAttackHit: state.options.isAttackHit,
                in: &context,
            ))
        case .stun:
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterStunDamageDealt(
                to: state.combatant,
                source: source.combatant,
                in: &context,
            ))
        case .burn:
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterBurnDamageDealt(
                to: state.combatant,
                source: source.combatant,
                in: &context,
            ))
        case .freeze:
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterFreezeDamageDealt(
                to: state.combatant,
                source: source.combatant,
                amount: state.healthLost,
                in: &context,
            ))
        default:
            break
        }
    }

    static func applyTalentDamageApplications(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let sourceRuntime = state.partySource(in: context),
              let keyword = state.damageKeyword
        else { return }
        let sourceActorID = sourceRuntime.id
        let source = sourceRuntime.combatant
        let triggers = context.modifiers(for: sourceActorID).triggers

        if keyword == .bleed, state.healthLost > 0, triggers.bleedDamageGoldFlat > 0 {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.bleedDamageGoldFlat,
                to: source,
                abilityName: "Cutpurse Knife",
            ))
        }

        if keyword == .holy {
            applyHolyStunReactions(
                to: &state,
                source: source,
                sourceActorID: sourceActorID,
                triggers: triggers,
                in: &context,
            )
        }

        guard state.options.isAttackHit else { return }
        applyPhysicalAttackReactions(
            to: &state,
            source: source,
            sourceActorID: sourceActorID,
            triggers: triggers,
            keyword: keyword,
            in: &context,
        )
        applyTalentAttackApplications(
            to: &state,
            source: source,
            sourceActorID: sourceActorID,
            triggers: triggers,
            keyword: keyword,
            in: &context,
        )
    }

    private static func applyPhysicalAttackReactions(
        to state: inout DamageResolutionState,
        source: Combatant,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        keyword: Keyword,
        in context: inout BattleState,
    ) {
        if keyword == .physical, state.buildupDamage > 0, triggers.physicalStunBuildupPercent > 0 {
            let buildup = CombatRounding.scaled(
                state.buildupDamage,
                multiplier: triggers.physicalStunBuildupPercent,
            )
            state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                buildup,
                keyword: .stun,
                to: state.combatant,
                sourceActorID: sourceActorID,
                applyFightPacing: false,
                in: &context,
            ))
        }
        if keyword == .physical, state.buildupDamage > 0, triggers.physicalDamageBlockPercent > 0 {
            let block = CombatRounding.scaled(
                state.buildupDamage,
                multiplier: triggers.physicalDamageBlockPercent,
            )
            if block > 0 {
                state.damageEvents.append(contentsOf: context.applyBlock(
                    block,
                    to: source,
                    source: source,
                    abilityName: "Vanguard's Crest",
                ))
            }
        }
    }

    private static func applyTalentAttackApplications(
        to state: inout DamageResolutionState,
        source: Combatant,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        keyword: Keyword,
        in context: inout BattleState,
    ) {
        let target = state.combatant
        let targetAlive = context.roster.health(for: target) > 0

        applyKeywordAfflictionApplications(
            to: &state,
            source: source,
            sourceActorID: sourceActorID,
            triggers: triggers,
            keyword: keyword,
            in: &context,
        )
        applyBasicAttackApplications(to: &state, source: source, sourceActorID: sourceActorID, triggers: triggers, in: &context)
        applyTargetStateReactions(
            to: &state,
            source: source,
            sourceActorID: sourceActorID,
            triggers: triggers,
            in: &context,
        )
        applyRandomOnHitApplications(
            to: &state,
            source: source,
            sourceActorID: sourceActorID,
            triggers: triggers,
            target: target,
            targetAlive: targetAlive,
            in: &context,
        )
    }

    private static func applyKeywordAfflictionApplications(
        to state: inout DamageResolutionState,
        source: Combatant,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        keyword: Keyword,
        in context: inout BattleState,
    ) {
        applyRangedAndPhysicalAfflictions(
            to: &state,
            source: source,
            sourceActorID: sourceActorID,
            triggers: triggers,
            keyword: keyword,
            in: &context,
        )
        applyHolyAfflictions(to: &state, sourceActorID: sourceActorID, triggers: triggers, keyword: keyword, in: &context)
    }

    private static func applyRangedAndPhysicalAfflictions(
        to state: inout DamageResolutionState,
        source: Combatant,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        keyword: Keyword,
        in context: inout BattleState,
    ) {
        let target = state.combatant
        let targetAlive = context.roster.health(for: target) > 0
        if triggers.attacksApplyPoison > 0, state.options.isBasicAttackHit, targetAlive {
            state.damageEvents.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: triggers.attacksApplyPoison,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
            ))
        }
        if triggers.physicalAttackApplyBleed > 0, keyword == .physical, targetAlive {
            state.damageEvents.append(contentsOf: DoTApplicator.applyBleed(
                potency: triggers.physicalAttackApplyBleed,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
                in: &context,
            ))
        }
        if triggers.physicalAttackApplyBleedAndStun > 0, keyword == .physical, targetAlive {
            state.damageEvents.append(contentsOf: DoTApplicator.applyBleed(
                potency: triggers.physicalAttackApplyBleedAndStun,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
                in: &context,
            ))
            state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                triggers.physicalAttackApplyBleedAndStun,
                keyword: .stun,
                to: target,
                sourceActorID: sourceActorID,
                applyFightPacing: false,
                in: &context,
            ))
        }
        if triggers.physicalAttackFlatStunBuildup > 0, keyword == .physical, targetAlive {
            state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                triggers.physicalAttackFlatStunBuildup,
                keyword: .stun,
                to: target,
                sourceActorID: sourceActorID,
                applyFightPacing: false,
                in: &context,
            ))
        }
        if triggers.onPhysicalDamageGainBlock > 0, keyword == .physical {
            state.damageEvents.append(contentsOf: context.applyBlock(
                triggers.onPhysicalDamageGainBlock,
                to: source,
                source: source,
                abilityName: "Bone Shield",
            ))
        }
    }

    private static func applyHolyAfflictions(
        to state: inout DamageResolutionState,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        keyword: Keyword,
        in context: inout BattleState,
    ) {
        let target = state.combatant
        guard keyword == .holy, context.roster.health(for: target) > 0, triggers.holyAttackApplyBurnAndStunBuildup > 0 else { return }
        state.damageEvents.append(contentsOf: context.applyDecayingDoT(
            keyword: .burn,
            potency: triggers.holyAttackApplyBurnAndStunBuildup,
            to: target,
            sourceActorID: sourceActorID,
            dealImmediateDamage: false,
            suppressAffixReactions: true,
        ))
        state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
            triggers.holyAttackApplyBurnAndStunBuildup,
            keyword: .stun,
            to: target,
            sourceActorID: sourceActorID,
            applyFightPacing: false,
            in: &context,
        ))
    }

    private static func applyBasicAttackApplications(
        to state: inout DamageResolutionState,
        source: Combatant,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        guard state.options.isBasicAttackHit, context.roster.health(for: state.combatant) > 0 else { return }
        let target = state.combatant
        if triggers.basicAttackApplyBleed > 0 {
            state.damageEvents.append(contentsOf: DoTApplicator.applyBleed(
                potency: triggers.basicAttackApplyBleed,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
                in: &context,
            ))
        }
        if triggers.basicAttackFreezeBuildup > 0 {
            state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                triggers.basicAttackFreezeBuildup,
                keyword: .freeze,
                to: target,
                sourceActorID: sourceActorID,
                applyFightPacing: false,
                in: &context,
            ))
        }
        if triggers.basicAttackStealGold > 0 {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.basicAttackStealGold,
                to: source,
                abilityName: "Snatch",
            ))
        }
    }

    private static func applyTargetStateReactions(
        to state: inout DamageResolutionState,
        source: Combatant,
        sourceActorID _: String,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        let target = state.combatant
        let targetAlive = context.roster.health(for: target) > 0
        let targetIsFrozen = context.roster.hasControlStatus(for: target, keyword: .freeze)
        let targetIsStunned = context.roster.hasControlStatus(for: target, keyword: .stun)
        let targetIsPoisoned = context.roster.hasAffliction(.poison, on: target)
        if triggers.onAttackStealGold > 0 {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.onAttackStealGold,
                to: source,
                abilityName: "Pickpocket",
            ))
        }
        if triggers.onAttackFrozenEnemyGainMana > 0, targetIsFrozen {
            state.damageEvents.append(contentsOf: context.restoreManaEmitting(
                triggers.onAttackFrozenEnemyGainMana,
                to: source,
                abilityName: "Frost Siphon",
            ))
        }
        if triggers.onAttackFrozenEnemyGainBlock > 0, targetIsFrozen {
            state.damageEvents.append(contentsOf: context.applyBlock(
                triggers.onAttackFrozenEnemyGainBlock,
                to: source,
                source: source,
                abilityName: "Frost Guard",
            ))
        }
        if triggers.onAttackStunnedEnemyGold > 0, targetIsStunned {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.onAttackStunnedEnemyGold,
                to: source,
                abilityName: "Disorienting Strike",
            ))
        }
        if triggers.onAttackStunnedEnemyBlock > 0, targetIsStunned {
            state.damageEvents.append(contentsOf: context.applyBlock(
                triggers.onAttackStunnedEnemyBlock,
                to: source,
                source: source,
                abilityName: "Disorienting Strike",
            ))
        }
        if source.role == .hero, targetIsPoisoned, targetAlive {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.companionSpitPoison(
                to: target,
                in: &context,
            ))
        }
    }

    private static func applyRandomOnHitApplications(
        to state: inout DamageResolutionState,
        source: Combatant,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        target: Combatant,
        targetAlive: Bool,
        in context: inout BattleState,
    ) {
        if triggers.directHitBleedChancePercent > 0, targetAlive,
           BattleChance.succeeds(probability: triggers.directHitBleedChancePercent, using: &context.rng) {
            state.damageEvents.append(contentsOf: DoTApplicator.applyBleed(
                potency: 1,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
                in: &context,
            ))
        }
        if triggers.attackApplyBleed > 0, state.options.qualifiesForAmbush, targetAlive {
            state.damageEvents.append(contentsOf: DoTApplicator.applyBleed(
                potency: triggers.attackApplyBleed,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
                in: &context,
            ))
        }
        if triggers.attackBurstChancePercent > 0, targetAlive,
           BattleChance.succeeds(probability: triggers.attackBurstChancePercent, using: &context.rng) {
            let burstDamage = max(0, triggers.attackBurstDamage)
            if burstDamage > 0 {
                state.damageEvents.append(contentsOf: context.resolveDamage(
                    DamageRequest(
                        amount: burstDamage,
                        target: target,
                        keyword: .physical,
                        sourceActorID: sourceActorID,
                        options: .flatReaction,
                    ),
                ).events)
            }
            let burstBlock = max(0, triggers.attackBurstBlock)
            if burstBlock > 0 {
                state.damageEvents.append(contentsOf: context.applyBlock(
                    burstBlock,
                    to: source,
                    source: source,
                    abilityName: "Bone Burst",
                ))
            }
        }
    }

    static func applyCriticalReaction(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.isCritical,
              state.healthLost > 0,
              let source = state.partySource(in: context),
              state.combatant.role == .enemy
        else { return }
        state.damageEvents.append(contentsOf: CombatTriggerEngine.afterCriticalHit(
            to: state.combatant,
            source: source.combatant,
            in: &context,
        ))
    }

    static func applyHolyStunReactions(
        to state: inout DamageResolutionState,
        source: Combatant,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        guard state.buildupDamage > 0, triggers.holyStunBuildupPercent > 0 else { return }
        let buildup = CombatRounding.scaled(
            state.buildupDamage,
            multiplier: triggers.holyStunBuildupPercent,
        )
        let stunEvents = ControlMeterEngine.applyMeterCharge(
            buildup,
            keyword: .stun,
            to: state.combatant,
            sourceActorID: sourceActorID,
            applyFightPacing: false,
            in: &context,
        )
        state.damageEvents.append(contentsOf: stunEvents)
        guard triggers.holyTriggeredStunGoldFlat > 0,
              stunEvents.contains(where: {
                  $0.effectKind == .controlTriggered && $0.keyword == .stun
              })
        else { return }
        state.damageEvents.append(contentsOf: context.grantGoldEvent(
            triggers.holyTriggeredStunGoldFlat,
            to: source,
            abilityName: CombatTriggerEngine.triggerAbilityName(
                "holyTriggeredStunGoldFlat",
                for: source,
                fallback: "Golden Verdict",
                in: context,
            ),
        ))
    }

    static func applyControlMeter(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.buildupDamage > 0,
              let damageKeyword = state.damageKeyword,
              damageKeyword == .stun || damageKeyword == .freeze,
              !state.options.isRetaliation || state.options.applyControlMeter,
              context.roster.health(for: state.combatant) > 0
        else { return }
        state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
            state.buildupDamage,
            keyword: damageKeyword,
            to: state.combatant,
            sourceActorID: state.sourceActorID,
            applyFightPacing: false,
            in: &context,
        ))
    }
}
