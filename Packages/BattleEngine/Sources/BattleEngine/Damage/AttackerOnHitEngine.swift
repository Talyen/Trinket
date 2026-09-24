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
    ) {
        applyStoredAdditionalDamage(to: &state, in: &context)
        guard let sourceRuntime = state.partySource(in: context),
              let keyword = state.damageKeyword
        else { return }
        let hit = Hit(
            source: sourceRuntime.combatant,
            keyword: keyword,
            triggers: context.modifiers(for: sourceRuntime.id).triggers,
        )

        if hit.keyword == .bleed, state.healthLost > 0, hit.triggers.bleedDamageGoldFlat > 0 {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                hit.triggers.bleedDamageGoldFlat,
                to: hit.source,
                abilityName: "Cutpurse Knife",
            ))
        }

        if state.healthLost > 0, state.combatant.role == .enemy,
           hit.triggers.carrionClaim, hit.keyword == .poison || hit.keyword == .bleed {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(1, to: hit.source, abilityName: "Carrion Claim", isTheft: true))
        }

        if hit.keyword == .holy {
            if hit.triggers.blindingLight, state.options.isAttackHit, !state.options.isRetaliation,
               state.combatant.role == .enemy {
                let reduction = CombatRounding.scaled(state.healthLost + state.blockedAmount, multiplier: 0.5)
                let current = context.heroTalents.history[state.combatant.id]?.blindingReduction ?? 0
                context.heroTalents.history[state.combatant.id, default: HeroTalentHistory()].blindingReduction = max(current, reduction)
            }
            applyHolyStunReactions(to: &state, hit: hit, in: &context)
        }

        applyPhysicalDamageReactions(to: &state, hit: hit, in: &context)
        guard state.options.isAttackHit else { return }
        applyTalentAttackApplications(to: &state, hit: hit, in: &context)
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
            state.damageEvents.append(contentsOf: DamagePipeline.resolveNestedDamage(
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
    ) {
        let triggers = hit.triggers
        if hit.keyword == .physical, state.healthLost > 0, triggers.physicalStunBuildupPercent > 0 {
            let buildup = CombatRounding.scaled(
                state.healthLost,
                multiplier: triggers.physicalStunBuildupPercent,
            )
            state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
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
                guard let source = state.partySource(in: context) else { return }
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
    ) {
        let triggers = hit.triggers
        guard state.remaining > 0, triggers.holyStunBuildupPercent > 0 else { return }
        let buildup = CombatRounding.scaled(
            state.remaining,
            multiplier: triggers.holyStunBuildupPercent,
        )
        let stunEvents = ControlMeterEngine.applyMeterCharge(
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
        state.damageEvents.append(contentsOf: context.grantGoldEvent(
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
    ) -> [ActionEvent] {
        context.healEmitting(
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
    ) {
        guard state.options.isAttackHit,
              let sourceActorID = state.sourceActorID,
              let attacker = context.roster.combatant(for: sourceActorID),
              let runtime = context.roster.runtime(for: attacker.combatant),
              runtime.talents.pending.bleedAfterDodge > 0
        else { return }
        let potency = runtime.talents.pending.bleedAfterDodge
        context.roster.mutateRuntime(for: attacker.combatant) { $0.talents.pending.bleedAfterDodge = 0 }
        appendTargetBleed(potency: potency, state: &state, context: &context)
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
