import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyTakeDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        let cap = context.modifiers(for: state.combatant.id).triggers.maxDamagePerHitCap
        state.remaining = DamageDefensePolicy.cappedDamage(state.remaining, operation: state.options, cap: cap)
        if applySacrificialGuard(to: &state, in: &context) {
            return
        }
        var lost = 0
        context.roster.mutateRuntime(for: state.combatant) { lost = $0.takeRawDamage(state.remaining) }
        state.healthLost = lost
        if lost > 0, state.combatant.role == .enemy, context.roster.health(for: state.combatant) == 0 {
            context.lastEnemyDefeatWasCritical = state.isCritical
            if state.targetStatus.isBleeding || state.damageKeyword == .bleed,
               let source = state.partySource(in: context) {
                let gold = context.modifiers(for: source.id).triggers.defeatBleedingEnemyGold
                if gold > 0 {
                    state.damageEvents.append(contentsOf: context.grantGoldEvent(
                        gold, to: source.combatant, abilityName: "Blood Money",
                    ))
                }
            }
        }
        if lost > 0 {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterHeroTalentHealthLoss(
                target: state.combatant, sourceID: state.sourceActorID, keyword: state.damageKeyword, in: &context,
            ))
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterHealthDropped(
                target: state.combatant,
                in: &context,
            ))
            state.damageEvents.append(contentsOf: applyTalentDamageReactions(
                defender: state.combatant,
                isRetaliation: state.options.isRetaliation,
                isAttackHit: state.options.isAttackHit,
                in: &context,
            ))
            state.damageEvents.append(contentsOf: applyCompanionLeechToHero(
                lost: lost,
                defender: state.combatant,
                sourceActorID: state.sourceActorID,
                in: &context,
            ))
        }
    }

    @discardableResult
    private static func applySacrificialGuard(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) -> Bool {
        guard !state.options.isHealthCost,
              state.combatant.role == .hero,
              state.remaining > 0,
              context.roster.health(for: state.combatant) <= state.remaining,
              context.roster.companion.isAlive,
              context.companionModifiers.triggers.companionFatalDamageRedirectBlock > 0
        else { return false }
        let redirected = state.remaining
        let companion = context.roster.companion.combatant
        state.damageEvents.append(contentsOf: context.resolveDamage(DamageRequest(
            amount: redirected,
            target: companion,
            keyword: state.damageKeyword ?? .physical,
            sourceActorID: state.sourceActorID,
            options: .redirected,
        )).events)
        if context.roster.companion.isAlive, !context.roster.isDeathsDoorActive(for: companion) {
            state.damageEvents.append(contentsOf: context.applyBlock(
                context.companionModifiers.triggers.companionFatalDamageRedirectBlock,
                to: companion,
                source: companion,
                abilityName: "Sacrificial Guard",
            ))
        }
        state.remaining = 0
        state.healthLost = 0
        return true
    }

    private static func applyTalentDamageReactions(
        defender: Combatant,
        isRetaliation: Bool,
        isAttackHit: Bool,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        let defenderTriggers = context.modifiers(for: defender.id).triggers
        if defender.role == .companion, context.roster.hero.isAlive,
           context.companionModifiers.triggers.onCompanionTakeDamageGrantHeroBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                context.companionModifiers.triggers.onCompanionTakeDamageGrantHeroBlock,
                to: context.roster.hero.combatant,
                source: context.roster.companion.combatant,
                abilityName: "Grizzly Guard",
            ))
        }
        if defenderTriggers.toughnessOnHit > 0, isAttackHit, !isRetaliation {
            context.roster.mutateRuntime(for: defender) { runtime in
                runtime.talents.battle.flatDamageReductionBonus += CombatGain.amount(
                    defenderTriggers.toughnessOnHit,
                    current: runtime.talents.battle.flatDamageReductionBonus, cap: defenderTriggers.toughnessOnHitCap,
                )
            }
        }
        if defender.role == .enemy, isAttackHit, !isRetaliation {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                guard member.isAlive else { continue }
                let amount = context.modifiers(for: member.id).triggers.onAnyHealthLossGainBlock
                if amount > 0 {
                    events.append(contentsOf: context.applyBlock(
                        amount,
                        to: member.combatant,
                        source: member.combatant,
                        abilityName: "Soul Ward",
                    ))
                }
            }
        }
        if defenderTriggers.onSelfHealthLossGainBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                defenderTriggers.onSelfHealthLossGainBlock,
                to: defender,
                source: defender,
                abilityName: "Bone Armor",
            ))
        }
        if defender.role != .enemy {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                guard member.isAlive, member.id != defender.id else { continue }
                let amount = context.modifiers(for: member.id).triggers.onAllyDamageHeal
                if amount > 0 {
                    events.append(contentsOf: HealingEngine.resolveHeal(
                        HealRequest(amount: amount, target: defender, sourceActorID: member.id),
                        in: &context,
                    ).events)
                }
            }
        }
        return events
    }

    private static func applyCompanionLeechToHero(
        lost: Int,
        defender: Combatant,
        sourceActorID: String?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard defender.role == .enemy,
              let sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              source.role == .companion,
              context.roster.hero.isAlive
        else { return [] }
        let percent = context.modifiers(for: source.combatant.id).triggers.companionDamageLeechesToHeroPercent
        guard percent > 0 else { return [] }
        let leechAmount = CombatRounding.scaled(lost, multiplier: min(1, max(0, percent)))
        guard leechAmount > 0 else { return [] }
        return context.healEmitting(
            amount: leechAmount,
            target: context.roster.hero.combatant,
            source: source.combatant,
            abilityName: "Soul Sharing",
            keyword: .leech,
        )
    }
}
