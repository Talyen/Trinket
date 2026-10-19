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
            _ = await context.grantGold(
                hit.triggers.bleedDamageGoldFlat,
                to: hit.source,
                abilityName: "Cutpurse Knife",
            )
        }

        if state.healthLost > 0, state.combatant.role == .enemy,
           hit.triggers.carrionClaim, hit.keyword == .poison || hit.keyword == .bleed {
            _ = await context.grantGold(
                1,
                to: hit.source,
                abilityName: "Carrion Claim",
                isTheft: true,
            )
        }

        if hit.keyword == .holy {
            if hit.triggers.blindingLight, state.options.isAttackHit, !state.options.isRetaliation,
               state.combatant.role == .enemy {
                let reduction = CombatRounding.scaled(state.healthLost + state.blockedAmount, multiplier: 0.5)
                let current = context.roster.runtime(for: state.combatant)?.talents.history.blindingReduction ?? 0
                context.roster.mutateRuntime(for: state.combatant) { $0.talents.history.blindingReduction = max(current, reduction) }
            }
            await applyHolyStunReactions(to: &state, hit: hit, in: &context)
        }

        await applyPhysicalDamageReactions(to: &state, hit: hit, in: &context)
        guard state.options.isAttackHit else { return }
        if hit.keyword == .physical, hit.triggers.prismaticEdge {
            await applyPrismaticEdge(to: &state, hit: hit, in: &context)
        }
        await applyTalentAttackApplications(to: &state, hit: hit, in: &context)
    }

    private static func applyPrismaticEdge(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) async {
        guard state.healthLost > 0,
              context.health(of: hit.source) > 0, context.health(of: state.combatant) > 0,
              let keyword = context.resolution.prismaticEdgeKeyword(for: hit.sourceActorID, using: &context.rng)
        else { return }
        // Copy committed Physical damage without applying source bonuses or pacing twice.
        let outcome = await context.resolveDamage(DamageRequest(
            amount: state.healthLost,
            target: state.combatant,
            keyword: keyword,
            sourceActorID: hit.sourceActorID,
            options: .copiedReaction,
        ))
        if outcome.healthLost > 0 {
            context.nextEvent(
                kind: .abilityDamage, source: .init(hit.source),
                abilityName: CombatTriggerEngine.triggerAbilityName(
                    .prismaticEdge,
                    for: hit.source,
                    fallback: "Prismatic Edge",
                    in: context,
                ),
                target: state.combatant, amount: outcome.healthLost, keyword: keyword,
            )
        }
        if keyword == .burn, outcome.healthLost > 0 {
            await context.applyDecayingDoT(
                keyword: .burn,
                potency: outcome.healthLost,
                to: state.combatant,
                sourceActorID: hit.sourceActorID,
                application: .attached,
            )
        }
    }

    private static func applyStoredAdditionalDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) async {
        guard state.additionalHolyDamage > 0 || state.additionalPhysicalDamage > 0,
              let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID)
        else { return }
        if state.additionalHolyDamage > 0 {
            _ = await DamagePipeline.resolveNestedDamage(
                amount: state.additionalHolyDamage,
                keyword: .holy,
                target: state.combatant,
                sourceActorID: sourceID,
                requireTargetAlive: true,
                requireSourceAlive: source.combatant,
                in: &context,
            )
        }
        if state.additionalPhysicalDamage > 0 {
            _ = await DamagePipeline.resolveNestedDamage(
                amount: state.additionalPhysicalDamage,
                keyword: .physical,
                target: state.combatant,
                sourceActorID: sourceID,
                requireTargetAlive: true,
                requireSourceAlive: source.combatant,
                in: &context,
            )
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
            await ControlMeterEngine.applyMeterCharge(
                buildup,
                keyword: .stun,
                to: state.combatant,
                sourceActorID: hit.sourceActorID,
                // Pacing already applied upstream in the damage pipeline;
                // the forwarder this replaced defaulted to false.
                applyFightPacing: false,
                in: &context,
            )
        }
        if hit.keyword == .physical, state.healthLost > 0, triggers.physicalDamageBlockPercent > 0 {
            let block = CombatRounding.scaled(
                state.healthLost,
                multiplier: triggers.physicalDamageBlockPercent,
            )
            if block > 0 {
                guard let source = state.partySource(in: context), source.isAlive else { return }
                context.applyBlockGain(
                    block, to: source.combatant, source: source.combatant,
                    abilityName: "Martial Guard", amountBasis: .resolved,
                )
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
        let stun = await ControlMeterEngine.applyMeterCharge(
            buildup,
            keyword: .stun,
            to: state.combatant,
            sourceActorID: hit.sourceActorID,
            applyFightPacing: false,
            in: &context,
        )
        guard context.health(of: hit.source) > 0, triggers.holyTriggeredStunGoldFlat > 0,
              stun.didTrigger
        else { return }
        _ = await context.grantGold(
            triggers.holyTriggeredStunGoldFlat,
            to: hit.source,
            abilityName: CombatTriggerEngine.triggerAbilityName(
                .holyTriggeredStunGoldFlat,
                for: hit.source,
                fallback: "Golden Verdict",
                in: context,
            ),
            isTheft: true,
        )
    }

    static func applyBleedingPreyHeal(
        triggers: CombatTraitTriggers,
        source: Combatant,
        in context: inout BattleState,
    ) async {
        await context.healEmitting(
            amount: triggers.onAttackBleedingEnemyHeal,
            target: source,
            source: source,
            abilityName: CombatTriggerEngine.triggerAbilityName(
                .onAttackBleedingEnemyHeal,
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
        await DoTApplicator.applyBleed(
            potency: potency,
            to: state.combatant,
            sourceActorID: sourceActorID,
            application: .attached,
            in: &context,
        )
    }

    /// Self-block fan-out for attacker on-hit riders: the attacker blocks.
    static func appendAttackerBlock(
        _ amount: Int,
        abilityName: String,
        state: inout DamageResolutionState,
        context: inout BattleState,
    ) {
        guard let source = state.partySource(in: context) else { return }
        context.applyBlockGain(amount, to: source.combatant, source: source.combatant, abilityName: abilityName)
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
            await context.applyDecayingDoT(
                keyword: .poison,
                potency: triggers.attacksApplyPoison,
                to: target,
                sourceActorID: hit.sourceActorID,
                application: .reaction,
            )
        }
        if triggers.physicalAttackApplyBleed > 0, hit.keyword == .physical,
           context.roster.health(for: target) > 0 {
            await appendTargetBleed(potency: triggers.physicalAttackApplyBleed, state: &state, context: &context)
        }
        if triggers.physicalAttackApplyBleedAndStun > 0, hit.keyword == .physical,
           context.roster.health(for: target) > 0 {
            await appendTargetBleed(potency: triggers.physicalAttackApplyBleedAndStun, state: &state, context: &context)
            await ControlMeterEngine.applyMeterCharge(
                triggers.physicalAttackApplyBleedAndStun,
                keyword: .stun,
                to: target,
                sourceActorID: hit.sourceActorID,
                applyFightPacing: false,
                in: &context,
            )
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
        await context.applyDecayingDoT(
            keyword: .burn,
            potency: triggers.holyAttackApplyBurnAndStunBuildup,
            to: target,
            sourceActorID: hit.sourceActorID,
            application: .reaction,
        )
        await ControlMeterEngine.applyMeterCharge(
            triggers.holyAttackApplyBurnAndStunBuildup,
            keyword: .stun,
            to: target,
            sourceActorID: hit.sourceActorID,
            applyFightPacing: false,
            in: &context,
        )
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
            var holyBonus = 0
            CombatTriggerEngine.forEachLivingAllyModifier(in: context) {
                holyBonus = SaturatedArithmetic.saturatingAdd(holyBonus, $0.triggers.partyBasicAttackHolyBonus)
            }
            _ = await DamagePipeline.resolveNestedDamage(
                amount: holyBonus,
                keyword: .holy,
                target: target,
                sourceActorID: hit.sourceActorID,
                requireTargetAlive: true,
                requireSourceAlive: hit.source,
                in: &context,
            )
        }
        if triggers.basicAttackApplyBleed > 0 {
            await appendTargetBleed(potency: triggers.basicAttackApplyBleed, state: &state, context: &context)
        }
        if triggers.basicAttackFreezeBuildup > 0 {
            _ = await DamagePipeline.resolveNestedDamage(
                amount: triggers.basicAttackFreezeBuildup,
                keyword: .freeze,
                target: target,
                sourceActorID: hit.sourceActorID,
                in: &context,
            )
        }
        if triggers.basicAttackStealGold > 0 {
            _ = await context.grantGold(
                triggers.basicAttackStealGold,
                to: hit.source,
                abilityName: "Snatch",
                isTheft: true,
                isDirectCardGain: state.options.isCardAttack,
            )
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
            _ = await context.grantGold(
                SaturatedArithmetic.saturatingAdd(
                    triggers.onAttackStealGold, targetIsPoisoned ? triggers.stealGoldBonusVsPoisoned : 0,
                ),
                to: hit.source,
                abilityName: "Pickpocket",
                isTheft: true,
                isDirectCardGain: state.options.isCardAttack,
            )
        }
        if triggers.onAttackBleedingEnemyHeal > 0, targetIsBleeding, targetAlive {
            await applyBleedingPreyHeal(triggers: triggers, source: hit.source, in: &context)
        }
        if triggers.onAttackFrozenEnemyGainMana > 0, targetIsFrozen {
            await context.restoreManaEmitting(triggers.onAttackFrozenEnemyGainMana, to: hit.source, abilityName: "Frost Siphon")
        }
        if triggers.onAttackFrozenEnemyGainBlock > 0, targetIsFrozen {
            appendAttackerBlock(triggers.onAttackFrozenEnemyGainBlock, abilityName: "Frost Guard", state: &state, context: &context)
        }
        if triggers.onAttackStunnedEnemyGold > 0, targetIsStunned {
            _ = await context.grantGold(
                triggers.onAttackStunnedEnemyGold,
                to: hit.source,
                abilityName: "Disorienting Strike",
            )
        }
        if triggers.onAttackStunnedEnemyBlock > 0, targetIsStunned {
            appendAttackerBlock(triggers.onAttackStunnedEnemyBlock, abilityName: "Disorienting Strike", state: &state, context: &context)
        }
        if hit.source.role == .hero, targetIsPoisoned, targetAlive {
            await CombatTriggerEngine.companionSpitPoison(to: target, in: &context)
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
        if triggers.dazingSwipeChancePercent > 0, triggers.dazingSwipeStunBuildup > 0,
           state.options.isAttackHit, state.damageKeyword == .physical,
           !state.options.isRetaliation, context.roster.health(for: target) > 0,
           context.claimTalentAbility(.dazingSwipe, actorID: hit.sourceActorID),
           BattleChance.succeeds(probability: triggers.dazingSwipeChancePercent, using: &context.rng) {
            await ControlMeterEngine.applyMeterCharge(
                triggers.dazingSwipeStunBuildup,
                keyword: .stun,
                to: target,
                sourceActorID: hit.sourceActorID,
                in: &context,
            )
        }
        if triggers.attackApplyBleed > 0, state.options.isAttackHit,
           context.roster.health(for: target) > 0 {
            await appendTargetBleed(potency: triggers.attackApplyBleed, state: &state, context: &context)
        }
        if triggers.attackBurstChancePercent > 0, context.roster.health(for: target) > 0,
           BattleChance.succeeds(probability: triggers.attackBurstChancePercent, using: &context.rng) {
            let burstDamage = max(0, triggers.attackBurstDamage)
            if burstDamage > 0 {
                _ = await DamagePipeline.resolveNestedDamage(
                    amount: burstDamage,
                    keyword: .physical,
                    target: target,
                    sourceActorID: hit.sourceActorID,
                    in: &context,
                )
            }
            let burstBlock = max(0, triggers.attackBurstBlock)
            if burstBlock > 0 {
                appendAttackerBlock(burstBlock, abilityName: "Bone Burst", state: &state, context: &context)
            }
        }
    }
}
