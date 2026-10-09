import Foundation
import TrinketContent
import TrinketCore

/// Attacker-owned riders at the committed-damage checkpoint. The pipeline
/// chooses when to run them; this owner keeps their internal order.
enum AttackerOnHitEngine {
    struct Hit {
        let source: Combatant
        let keyword: Keyword
        let triggers: CombatTraitTriggers

        var sourceActorID: String {
            source.id
        }
    }

    static func apply(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) async {
        await applyStoredAdditionalDamage(to: &state, in: &context)
        guard let sourceRuntime = state.partySource(in: context),
              let keyword = state.damageKeyword
        else { return }
        let hit = Hit(
            source: sourceRuntime.combatant,
            keyword: keyword,
            triggers: context.modifiers(for: sourceRuntime.id).triggers,
        )

        if hit.keyword == .bleed, state.healthLost > 0, hit.triggers.bleedDamageGoldFlat > 0,
           context.roster.health(for: hit.source) > 0 {
            await state.damageEvents.append(contentsOf: context.grantGoldEvent(
                hit.triggers.bleedDamageGoldFlat,
                to: hit.source,
                abilityName: "Cutpurse Knife",
            ))
        }

        if state.healthLost > 0, state.combatant.role == .enemy,
           hit.triggers.carrionClaim, hit.keyword == .poison || hit.keyword == .bleed {
            await state.damageEvents.append(contentsOf: context.grantGoldEvent(
                1,
                to: hit.source,
                abilityName: "Carrion Claim",
                isTheft: true,
            ))
        }

        if hit.keyword == .holy {
            if hit.triggers.blindingLight, state.options.isAttackHit, !state.options.isRetaliation,
               state.combatant.role == .enemy {
                let reduction = CombatRounding.scaled(state.healthLost + state.blockedAmount, multiplier: 0.5)
                let current = context.heroTalents.history[state.combatant.id]?.blindingReduction ?? 0
                context.heroTalents.history[state.combatant.id, default: HeroTalentHistory()].blindingReduction = max(current, reduction)
            }
            await applyHolyStunReactions(to: &state, hit: hit, in: &context)
        }

        await applyPhysicalDamageReactions(to: &state, hit: hit, in: &context)
        guard state.options.isAttackHit else { return }
        await applyTalentAttackApplications(to: &state, hit: hit, in: &context)
    }

    private static func applyStoredAdditionalDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) async {
        guard let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID)
        else { return }
        for (bonus, keyword) in [
            (state.additionalHolyDamage, Keyword.holy),
            (state.additionalPhysicalDamage, Keyword.physical),
        ] {
            await state.damageEvents.append(contentsOf: DamagePipeline.resolveNestedDamage(
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
        hit: Hit,
        in context: inout BattleState,
    ) async {
        let triggers = hit.triggers
        if hit.keyword == .physical, state.healthLost > 0, triggers.physicalStunBuildupPercent > 0 {
            let buildup = CombatRounding.scaled(
                state.healthLost,
                multiplier: triggers.physicalStunBuildupPercent,
            )
            await state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                buildup,
                keyword: .stun,
                to: state.combatant,
                sourceActorID: hit.sourceActorID,
                // Pacing already applied upstream in the damage pipeline;
                // the forwarder this replaced defaulted to false.
                applyFightPacing: false,
                in: &context,
            ))
        }
        if hit.keyword == .physical, state.healthLost > 0, triggers.physicalDamageBlockPercent > 0 {
            let block = CombatRounding.scaled(
                state.healthLost,
                multiplier: triggers.physicalDamageBlockPercent,
            )
            if block > 0 {
                guard let source = state.partySource(in: context), source.isAlive else { return }
                state.damageEvents.append(contentsOf: context.applyBlock(
                    block, to: source.combatant, source: source.combatant,
                    abilityName: "Martial Guard", amountBasis: .resolved,
                ))
            }
        }
    }

    private static func applyHolyStunReactions(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) async {
        let triggers = hit.triggers
        guard state.remaining > 0, triggers.holyStunBuildupPercent > 0 else { return }
        let buildup = CombatRounding.scaled(
            state.remaining,
            multiplier: triggers.holyStunBuildupPercent,
        )
        let stunEvents = await ControlMeterEngine.applyMeterCharge(
            buildup,
            keyword: .stun,
            to: state.combatant,
            sourceActorID: hit.sourceActorID,
            applyFightPacing: false,
            in: &context,
        )
        state.damageEvents.append(contentsOf: stunEvents)
        guard triggers.holyTriggeredStunGoldFlat > 0,
              stunEvents.contains(where: {
                  $0.effectKind == .controlTriggered && $0.keyword == .stun
              })
        else { return }
        await state.damageEvents.append(contentsOf: context.grantGoldEvent(
            triggers.holyTriggeredStunGoldFlat,
            to: hit.source,
            abilityName: CombatTriggerEngine.triggerAbilityName(
                "holyTriggeredStunGoldFlat",
                for: hit.source,
                fallback: "Golden Verdict",
                in: context,
            ),
            isTheft: true,
        ))
    }

    static func applyBleedingPreyHeal(
        triggers: CombatTraitTriggers,
        source: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        await context.healEmitting(
            amount: triggers.onAttackBleedingEnemyHeal,
            target: source,
            source: source,
            abilityName: CombatTriggerEngine.triggerAbilityName(
                "onAttackBleedingEnemyHeal",
                for: source,
                fallback: "Bloodprice",
                in: context,
            ),
        )
    }

    static func applyNimbleFang(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) async {
        guard state.options.isAttackHit,
              let sourceActorID = state.sourceActorID,
              let attacker = context.roster.combatant(for: sourceActorID),
              let runtime = context.roster.runtime(for: attacker.combatant),
              runtime.talents.pending.bleedAfterDodge > 0
        else { return }
        let potency = runtime.talents.pending.bleedAfterDodge
        context.roster.mutateRuntime(for: attacker.combatant) { $0.talents.pending.bleedAfterDodge = 0 }
        await appendTargetBleed(potency: potency, state: &state, context: &context)
    }

    /// Attached-bleed fan-out for attacker on-hit riders: the target is
    /// always the damage recipient and the source the pipeline attacker.
    static func appendTargetBleed(
        potency: Int,
        state: inout DamageResolutionState,
        context: inout BattleState,
    ) async {
        guard let sourceActorID = state.sourceActorID else { return }
        await state.damageEvents.append(contentsOf: DoTApplicator.applyBleed(
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

extension AttackerOnHitEngine {
    private static func applyTalentAttackApplications(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) async {
        await applyRangedAndPhysicalAfflictions(to: &state, hit: hit, in: &context)
        await applyHolyAfflictions(to: &state, hit: hit, in: &context)
        await applyBasicAttackApplications(to: &state, hit: hit, in: &context)
        await applyTargetStateReactions(to: &state, hit: hit, in: &context)
        await applyRandomOnHitApplications(to: &state, hit: hit, in: &context)
    }

    private static func applyRangedAndPhysicalAfflictions(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) async {
        let triggers = hit.triggers
        let target = state.combatant
        if triggers.attacksApplyPoison > 0, state.options.isAttackHit,
           context.roster.health(for: target) > 0 {
            await state.damageEvents.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: triggers.attacksApplyPoison,
                to: target,
                sourceActorID: hit.sourceActorID,
                application: .reaction,
            ))
        }
        if triggers.physicalAttackApplyBleed > 0, hit.keyword == .physical,
           context.roster.health(for: target) > 0 {
            await appendTargetBleed(potency: triggers.physicalAttackApplyBleed, state: &state, context: &context)
        }
        if triggers.physicalAttackApplyBleedAndStun > 0, hit.keyword == .physical,
           context.roster.health(for: target) > 0 {
            await appendTargetBleed(potency: triggers.physicalAttackApplyBleedAndStun, state: &state, context: &context)
            await state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                triggers.physicalAttackApplyBleedAndStun,
                keyword: .stun,
                to: target,
                sourceActorID: hit.sourceActorID,
                applyFightPacing: false,
                in: &context,
            ))
        }
        if triggers.onPhysicalDamageGainBlock > 0, hit.keyword == .physical {
            appendAttackerBlock(triggers.onPhysicalDamageGainBlock, abilityName: "Bone Shield", state: &state, context: &context)
        }
    }

    private static func applyHolyAfflictions(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) async {
        let triggers = hit.triggers
        let target = state.combatant
        guard hit.keyword == .holy, context.roster.health(for: target) > 0, triggers.holyAttackApplyBurnAndStunBuildup > 0 else { return }
        await state.damageEvents.append(contentsOf: context.applyDecayingDoT(
            keyword: .burn,
            potency: triggers.holyAttackApplyBurnAndStunBuildup,
            to: target,
            sourceActorID: hit.sourceActorID,
            application: .reaction,
        ))
        await state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
            triggers.holyAttackApplyBurnAndStunBuildup,
            keyword: .stun,
            to: target,
            sourceActorID: hit.sourceActorID,
            applyFightPacing: false,
            in: &context,
        ))
    }

    private static func applyBasicAttackApplications(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) async {
        let triggers = hit.triggers
        guard state.options.isBasicAttackHit, context.roster.health(for: state.combatant) > 0 else { return }
        let target = state.combatant
        if state.damageKeyword != .holy {
            let holyBonus = CombatTriggerEngine.livingAllyModifiers(in: context)
                .reduce(0) { $0 + $1.triggers.partyBasicAttackHolyBonus }
            await state.damageEvents.append(contentsOf: DamagePipeline.resolveNestedDamage(
                amount: holyBonus,
                keyword: .holy,
                target: target,
                sourceActorID: hit.sourceActorID,
                requireTargetAlive: true,
                requireSourceAlive: hit.source,
                in: &context,
            ).events)
        }
        if triggers.basicAttackApplyBleed > 0 {
            await appendTargetBleed(potency: triggers.basicAttackApplyBleed, state: &state, context: &context)
        }
        if triggers.basicAttackFreezeBuildup > 0 {
            await state.damageEvents.append(contentsOf: DamagePipeline.resolveNestedDamage(
                amount: triggers.basicAttackFreezeBuildup,
                keyword: .freeze,
                target: target,
                sourceActorID: hit.sourceActorID,
                in: &context,
            ).events)
        }
        if triggers.basicAttackStealGold > 0 {
            await state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.basicAttackStealGold,
                to: hit.source,
                abilityName: "Snatch",
                isTheft: true,
                isDirectCardGain: state.options.isCardAttack,
            ))
        }
    }

    private static func applyTargetStateReactions(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) async {
        let triggers = hit.triggers
        let target = state.combatant
        let targetAlive = context.roster.health(for: target) > 0
        let targetIsFrozen = context.roster.hasControlStatus(for: target, keyword: .freeze)
        let targetIsStunned = context.roster.hasControlStatus(for: target, keyword: .stun)
        let targetIsPoisoned = context.roster.hasAffliction(.poison, on: target)
        let targetIsBleeding = context.roster.hasAffliction(.bleed, on: target)
        if triggers.onAttackStealGold > 0 {
            await state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.onAttackStealGold + (targetIsPoisoned ? triggers.stealGoldBonusVsPoisoned : 0),
                to: hit.source,
                abilityName: "Pickpocket",
                isTheft: true,
                isDirectCardGain: state.options.isCardAttack,
            ))
        }
        if triggers.onAttackBleedingEnemyHeal > 0, targetIsBleeding, targetAlive {
            await state.damageEvents.append(contentsOf: applyBleedingPreyHeal(
                triggers: triggers,
                source: hit.source,
                in: &context,
            ))
        }
        if triggers.onAttackFrozenEnemyGainMana > 0, targetIsFrozen {
            await state.damageEvents.append(contentsOf: context.restoreManaEmitting(
                triggers.onAttackFrozenEnemyGainMana,
                to: hit.source,
                abilityName: "Frost Siphon",
            ))
        }
        if triggers.onAttackFrozenEnemyGainBlock > 0, targetIsFrozen {
            appendAttackerBlock(triggers.onAttackFrozenEnemyGainBlock, abilityName: "Frost Guard", state: &state, context: &context)
        }
        if triggers.onAttackStunnedEnemyGold > 0, targetIsStunned {
            await state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.onAttackStunnedEnemyGold,
                to: hit.source,
                abilityName: "Disorienting Strike",
            ))
        }
        if triggers.onAttackStunnedEnemyBlock > 0, targetIsStunned {
            appendAttackerBlock(triggers.onAttackStunnedEnemyBlock, abilityName: "Disorienting Strike", state: &state, context: &context)
        }
        if hit.source.role == .hero, targetIsPoisoned, targetAlive {
            await state.damageEvents.append(contentsOf: CombatTriggerEngine.companionSpitPoison(
                to: target,
                in: &context,
            ))
        }
    }

    private static func applyRandomOnHitApplications(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) async {
        let triggers = hit.triggers
        let target = state.combatant
        if triggers.directHitBleedChancePercent > 0, context.roster.health(for: target) > 0,
           BattleChance.succeeds(probability: triggers.directHitBleedChancePercent, using: &context.rng) {
            await appendTargetBleed(potency: 1, state: &state, context: &context)
        }
        if triggers.dazingSwipeChancePercent > 0, triggers.dazingSwipeStunDamage > 0,
           state.options.isAttackHit, state.damageKeyword == .physical,
           !state.options.isRetaliation, context.roster.health(for: target) > 0,
           context.claimTalentAbility(.dazingSwipe, actorID: hit.sourceActorID),
           BattleChance.succeeds(probability: triggers.dazingSwipeChancePercent, using: &context.rng) {
            await state.damageEvents.append(contentsOf: DamagePipeline.resolveNestedDamage(
                amount: triggers.dazingSwipeStunDamage,
                keyword: .stun,
                target: target,
                sourceActorID: hit.sourceActorID,
                in: &context,
            ).events)
        }
        if triggers.attackApplyBleed > 0, state.options.isAttackHit,
           context.roster.health(for: target) > 0 {
            await appendTargetBleed(potency: triggers.attackApplyBleed, state: &state, context: &context)
        }
        if triggers.attackBurstChancePercent > 0, context.roster.health(for: target) > 0,
           BattleChance.succeeds(probability: triggers.attackBurstChancePercent, using: &context.rng) {
            let burstDamage = max(0, triggers.attackBurstDamage)
            if burstDamage > 0 {
                await state.damageEvents.append(contentsOf: DamagePipeline.resolveNestedDamage(
                    amount: burstDamage,
                    keyword: .physical,
                    target: target,
                    sourceActorID: hit.sourceActorID,
                    in: &context,
                ).events)
            }
            let burstBlock = max(0, triggers.attackBurstBlock)
            if burstBlock > 0 {
                appendAttackerBlock(burstBlock, abilityName: "Bone Burst", state: &state, context: &context)
            }
        }
    }
}
