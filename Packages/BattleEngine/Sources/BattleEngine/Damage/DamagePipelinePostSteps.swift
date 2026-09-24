import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyLeech(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard !state.options.suppressLeech,
              let sourceActorID = state.sourceActorID,
              state.healthLost > 0 || (state.blockedAmount > 0 && context.modifiers(for: sourceActorID).triggers.leechOnBlockDamage),
              sourceActorID != state.combatant.id
        else { return }
        let leechOutcome = HealingEngine.leechFromDamage(
            state.healthLost,
            sourceActorID: sourceActorID,
            target: state.combatant,
            blockedAmount: state.blockedAmount,
            abilityHasLeech: state.options.abilityHasLeech || state.talentAttackHasLeech,
            criticalAttack: state.isCritical && state.options.isAttackHit,
            attackHit: state.options.isAttackHit,
            damageKeyword: state.damageKeyword,
            in: &context,
        )
        state.damageEvents.append(contentsOf: leechOutcome.events)
        state.didLeech = leechOutcome.flags.contains(.leeched)
        applyFinalCompanionLeechRewards(to: &state, in: &context)
    }

    static func applyKeywordReactions(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.healthLost > 0,
              let keyword = state.damageKeyword,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID)
        else { return }

        switch keyword {
        case .holy:
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterHolyDamageDealt(
                to: state.combatant,
                source: source.combatant,
                attackHit: state.options.isAttackHit && !state.options.isRetaliation,
                sourceHadNoBlock: state.sourceHadNoBlockAtHit,
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
                healthLost: state.healthLost,
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

        guard state.combatant.role == .enemy, source.combatant.role != .enemy,
              keyword == .burn || keyword == .freeze || keyword == .holy else { return }
        for owner in [BattleParticipant.hero, .companion] {
            let wearer = context.roster[owner]
            guard wearer.isAlive, wearer.currentMana < wearer.maxMana else { continue }
            let chance = context.modifiers(for: wearer.combatant.id).triggers.threefoldElementalDamageManaChancePercent
            guard chance > 0, BattleChance.succeeds(probability: chance, using: &context.rng) else { continue }
            state.damageEvents.append(contentsOf: context.restoreManaEmitting(
                1,
                to: wearer.combatant,
                abilityName: "Threefold Grace",
            ))
        }
    }

    static func applyAttackerOnHitApplications(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        applyStoredAdditionalDamage(to: &state, in: &context)
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

        if state.healthLost > 0, state.combatant.role == .enemy,
           triggers.carrionClaim, keyword == .poison || keyword == .bleed {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(1, to: source, abilityName: "Carrion Claim", isTheft: true))
        }

        if keyword == .holy {
            if triggers.blindingLight, state.options.isAttackHit, !state.options.isRetaliation,
               state.combatant.role == .enemy {
                let reduction = CombatRounding.scaled(state.healthLost + state.blockedAmount, multiplier: 0.5)
                let current = context.heroTalents.history[state.combatant.id]?.blindingReduction ?? 0
                context.heroTalents.history[state.combatant.id, default: HeroTalentHistory()].blindingReduction = max(current, reduction)
            }
            applyHolyStunReactions(
                to: &state,
                source: source,
                sourceActorID: sourceActorID,
                triggers: triggers,
                in: &context,
            )
        }

        applyPhysicalDamageReactions(
            to: &state,
            sourceActorID: sourceActorID,
            triggers: triggers,
            keyword: keyword,
            in: &context,
        )
        guard state.options.isAttackHit else { return }
        applyTalentAttackApplications(
            to: &state,
            source: source,
            sourceActorID: sourceActorID,
            triggers: triggers,
            keyword: keyword,
            in: &context,
        )
    }

    private static func applyStoredAdditionalDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID)
        else { return }
        for (bonus, keyword) in [
            (state.additionalHolyDamage, Keyword.holy),
            (state.additionalPhysicalDamage, Keyword.physical),
        ] {
            state.damageEvents.append(contentsOf: resolveNestedDamage(
                amount: bonus,
                keyword: keyword,
                target: state.combatant,
                sourceActorID: sourceID,
                requireTargetAlive: true,
                requireSourceAlive: source.combatant,
                in: &context,
            ).events)
        }
    }

    private static func applyPhysicalDamageReactions(
        to state: inout DamageResolutionState,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        keyword: Keyword,
        in context: inout BattleState,
    ) {
        if keyword == .physical, state.healthLost > 0, triggers.physicalStunBuildupPercent > 0 {
            let buildup = CombatRounding.scaled(
                state.healthLost,
                multiplier: triggers.physicalStunBuildupPercent,
            )
            state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                buildup,
                keyword: .stun,
                to: state.combatant,
                sourceActorID: sourceActorID,
                // Pacing already applied upstream in the damage pipeline;
                // the forwarder this replaced defaulted to false.
                applyFightPacing: false,
                in: &context,
            ))
        }
        if keyword == .physical, state.healthLost > 0, triggers.physicalDamageBlockPercent > 0 {
            let block = CombatRounding.scaled(
                state.healthLost,
                multiplier: triggers.physicalDamageBlockPercent,
            )
            if block > 0 {
                guard let source = state.partySource(in: context) else { return }
                state.damageEvents.append(contentsOf: context.applyBlock(
                    block, to: source.combatant, source: source.combatant,
                    abilityName: "Martial Guard", amountBasis: .resolved,
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

        applyRangedAndPhysicalAfflictions(
            to: &state,
            sourceActorID: sourceActorID,
            triggers: triggers,
            keyword: keyword,
            in: &context,
        )
        applyHolyAfflictions(to: &state, sourceActorID: sourceActorID, triggers: triggers, keyword: keyword, in: &context)
        applyBasicAttackApplications(to: &state, source: source, sourceActorID: sourceActorID, triggers: triggers, in: &context)
        applyTargetStateReactions(
            to: &state,
            source: source,
            triggers: triggers,
            in: &context,
        )
        applyRandomOnHitApplications(
            to: &state,
            sourceActorID: sourceActorID,
            triggers: triggers,
            target: target,
            targetAlive: targetAlive,
            in: &context,
        )
    }

    private static func applyRangedAndPhysicalAfflictions(
        to state: inout DamageResolutionState,
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
                application: .reaction,
            ))
        }
        if triggers.physicalAttackApplyBleed > 0, keyword == .physical, targetAlive {
            appendTargetBleed(potency: triggers.physicalAttackApplyBleed, state: &state, context: &context)
        }
        if triggers.physicalAttackApplyBleedAndStun > 0, keyword == .physical, targetAlive {
            appendTargetBleed(potency: triggers.physicalAttackApplyBleedAndStun, state: &state, context: &context)
            state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                triggers.physicalAttackApplyBleedAndStun,
                keyword: .stun,
                to: target,
                sourceActorID: sourceActorID,
                applyFightPacing: false,
                in: &context,
            ))
        }
        if triggers.onPhysicalDamageGainBlock > 0, keyword == .physical {
            appendAttackerBlock(triggers.onPhysicalDamageGainBlock, abilityName: "Bone Shield", state: &state, context: &context)
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
            application: .reaction,
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
        if state.damageKeyword != .holy {
            let holyBonus = CombatTriggerEngine.livingAllyModifiers(in: context)
                .reduce(0) { $0 + $1.triggers.partyBasicAttackHolyBonus }
            state.damageEvents.append(contentsOf: resolveNestedDamage(
                amount: holyBonus,
                keyword: .holy,
                target: target,
                sourceActorID: sourceActorID,
                requireTargetAlive: true,
                requireSourceAlive: source,
                in: &context,
            ).events)
        }
        if triggers.basicAttackApplyBleed > 0 {
            appendTargetBleed(potency: triggers.basicAttackApplyBleed, state: &state, context: &context)
        }
        if triggers.basicAttackFreezeBuildup > 0 {
            state.damageEvents.append(contentsOf: resolveNestedDamage(
                amount: triggers.basicAttackFreezeBuildup,
                keyword: .freeze,
                target: target,
                sourceActorID: sourceActorID,
                in: &context,
            ).events)
        }
        if triggers.basicAttackStealGold > 0 {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.basicAttackStealGold,
                to: source,
                abilityName: "Snatch",
                isTheft: true,
                isDirectCardGain: state.options.isCardAttack,
            ))
        }
    }

    private static func applyTargetStateReactions(
        to state: inout DamageResolutionState,
        source: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        let target = state.combatant
        let targetAlive = context.roster.health(for: target) > 0
        let targetIsFrozen = context.roster.hasControlStatus(for: target, keyword: .freeze)
        let targetIsStunned = context.roster.hasControlStatus(for: target, keyword: .stun)
        let targetIsPoisoned = context.roster.hasAffliction(.poison, on: target)
        let targetIsBleeding = context.roster.hasAffliction(.bleed, on: target)
        if triggers.onAttackStealGold > 0 {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.onAttackStealGold + (targetIsPoisoned ? triggers.stealGoldBonusVsPoisoned : 0),
                to: source,
                abilityName: "Pickpocket",
                isTheft: true,
                isDirectCardGain: state.options.isCardAttack,
            ))
        }
        if triggers.onAttackBleedingEnemyHeal > 0, targetIsBleeding, targetAlive {
            state.damageEvents.append(contentsOf: applyBleedingPreyHeal(
                triggers: triggers,
                source: source,
                in: &context,
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
            appendAttackerBlock(triggers.onAttackFrozenEnemyGainBlock, abilityName: "Frost Guard", state: &state, context: &context)
        }
        if triggers.onAttackStunnedEnemyGold > 0, targetIsStunned {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.onAttackStunnedEnemyGold,
                to: source,
                abilityName: "Disorienting Strike",
            ))
        }
        if triggers.onAttackStunnedEnemyBlock > 0, targetIsStunned {
            appendAttackerBlock(triggers.onAttackStunnedEnemyBlock, abilityName: "Disorienting Strike", state: &state, context: &context)
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
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        target: Combatant,
        targetAlive: Bool,
        in context: inout BattleState,
    ) {
        if triggers.directHitBleedChancePercent > 0, targetAlive,
           BattleChance.succeeds(probability: triggers.directHitBleedChancePercent, using: &context.rng) {
            appendTargetBleed(potency: 1, state: &state, context: &context)
        }
        if triggers.dazingSwipeChancePercent > 0, triggers.dazingSwipeStunDamage > 0,
           state.options.isAttackHit, state.damageKeyword == .physical,
           !state.options.isRetaliation, targetAlive,
           context.claimTalentAbility("Dazing Swipe", actorID: sourceActorID),
           BattleChance.succeeds(probability: triggers.dazingSwipeChancePercent, using: &context.rng) {
            state.damageEvents.append(contentsOf: resolveNestedDamage(
                amount: triggers.dazingSwipeStunDamage,
                keyword: .stun,
                target: target,
                sourceActorID: sourceActorID,
                in: &context,
            ).events)
        }
        if triggers.attackApplyBleed > 0, state.options.isAttackHit, targetAlive {
            appendTargetBleed(potency: triggers.attackApplyBleed, state: &state, context: &context)
        }
        if triggers.attackBurstChancePercent > 0, targetAlive,
           BattleChance.succeeds(probability: triggers.attackBurstChancePercent, using: &context.rng) {
            let burstDamage = max(0, triggers.attackBurstDamage)
            if burstDamage > 0 {
                state.damageEvents.append(contentsOf: resolveNestedDamage(
                    amount: burstDamage,
                    keyword: .physical,
                    target: target,
                    sourceActorID: sourceActorID,
                    in: &context,
                ).events)
            }
            let burstBlock = max(0, triggers.attackBurstBlock)
            if burstBlock > 0 {
                appendAttackerBlock(burstBlock, abilityName: "Bone Burst", state: &state, context: &context)
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
        guard state.remaining > 0, triggers.holyStunBuildupPercent > 0 else { return }
        let buildup = CombatRounding.scaled(
            state.remaining,
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
            isTheft: true,
        ))
    }

    static func applyControlMeter(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0,
              let damageKeyword = state.damageKeyword,
              damageKeyword == .stun || damageKeyword == .freeze,
              context.roster.health(for: state.combatant) > 0
        else { return }
        let wasControlled = context.roster.hasControlStatus(for: state.combatant, keyword: damageKeyword)
        let criticalMultiplier: Double = if damageKeyword == .freeze, state.isCritical, state.options.isAttackHit,
                                            let sourceActorID = state.sourceActorID {
            context.modifiers(for: sourceActorID).triggers.freezeCriticalBuildupMultiplier
        } else {
            1
        }
        state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
            CombatRounding.scaled(state.remaining, multiplier: criticalMultiplier),
            keyword: damageKeyword,
            to: state.combatant,
            sourceActorID: state.sourceActorID,
            applyFightPacing: false,
            in: &context,
        ))
        state.didTriggerControl = !wasControlled && context.roster.hasControlStatus(for: state.combatant, keyword: damageKeyword)
    }

    /// Attached-bleed fan-out for attacker on-hit riders: the target is
    /// always the damage recipient and the source the pipeline attacker.
    static func appendTargetBleed(
        potency: Int,
        state: inout DamageResolutionState,
        context: inout BattleState,
    ) {
        guard let sourceActorID = state.sourceActorID else { return }
        state.damageEvents.append(contentsOf: DoTApplicator.applyBleed(
            potency: potency,
            to: state.combatant,
            sourceActorID: sourceActorID,
            application: .attached,
            in: &context,
        ))
    }

    /// Self-block fan-out for attacker on-hit riders: the attacker blocks.
    static func appendAttackerBlock(
        _ amount: Int,
        abilityName: String,
        state: inout DamageResolutionState,
        context: inout BattleState,
    ) {
        guard let source = state.partySource(in: context) else { return }
        state.damageEvents.append(contentsOf: context.applyBlock(
            amount,
            to: source.combatant,
            source: source.combatant,
            abilityName: abilityName,
        ))
    }
}
