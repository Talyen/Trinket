import Foundation
import TrinketContent
import TrinketCore

package enum ControlMeterEngine {
    package static func applyMeterCharge( // swiftlint:disable:this function_body_length
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        applyFightPacing: Bool = true,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0, context.roster.health(for: combatant) > 0 else { return [] }
        if context.roster.hasControlStatus(for: combatant, keyword: keyword) {
            return []
        }
        let pacedAmount = applyFightPacing
            ? (sourceActorID.map { context.paced(amount, sourceActorID: $0) } ?? amount)
            : amount
        guard pacedAmount > 0 else { return [] }

        var adjustedAmount = pacedAmount
        if keyword == .stun || keyword == .freeze {
            let targetTriggers = context.modifiers(for: combatant.id).triggers
            let steadfastResistance = targetTriggers.blockedControlBurnResistance > 0
                && DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: combatant)) > 0
                ? targetTriggers.blockedControlBurnResistance
                : 0
            let lichboneResistance = keyword == .stun ? targetTriggers.afflictionResistance : 0
            let partyResistance: Double = switch combatant.role {
            case .hero, .companion: PrimaryStats.partyIncomingControlResistance
            case .enemy: 0
            }
            let controlResistance = 1 - (1 - partyResistance) * (1 - steadfastResistance) * (1 - lichboneResistance)
            if controlResistance > 0 {
                adjustedAmount = CombatRounding.scaled(adjustedAmount, multiplier: 1 - min(1, controlResistance))
            }
        }
        guard adjustedAmount > 0 else { return [] }

        let threshold = threshold(for: combatant, in: context)
        let effectiveThreshold: Int = if keyword == .stun, combatant.role == .enemy, let sourceActorID,
                                         context.modifiers(for: sourceActorID).triggers.enemyStunThresholdReductionPercent > 0 {
            CombatRounding.scaled(
                threshold,
                multiplier: 1 - min(1, context.modifiers(for: sourceActorID).triggers.enemyStunThresholdReductionPercent),
            )
        } else {
            threshold
        }
        var currentEffects = context.roster.activeEffects(for: combatant)
        guard !context.interceptDebuff(
            .controlMeter(keyword, adjustedAmount, effectiveThreshold),
            on: combatant,
        ) else { return [] }
        let existingIndex = currentEffects.firstIndex { activeEffect in
            if case let .controlMeter(k, _, _) = activeEffect.effect, k == keyword {
                return true
            }
            return false
        }
        let existingAmount = existingMeterAmount(at: existingIndex, in: currentEffects)
        guard existingAmount < effectiveThreshold else { return [] }
        let newAmount = min(existingAmount + adjustedAmount, effectiveThreshold)

        if newAmount >= effectiveThreshold {
            return applyThresholdReached(
                ControlMeterThresholdContext(
                    keyword: keyword,
                    combatant: combatant,
                    sourceActorID: sourceActorID,
                    existingIndex: existingIndex,
                    baseThreshold: threshold,
                ),
                currentEffects: &currentEffects,
                in: &context,
            )
        }

        updateBuildup(
            ControlMeterUpdate(
                keyword: keyword,
                newAmount: newAmount,
                threshold: threshold,
                combatant: combatant,
                sourceActorID: sourceActorID,
                existingIndex: existingIndex,
            ),
            currentEffects: &currentEffects,
            in: &context,
        )
        return []
    }

    package static func threshold(for combatant: Combatant, in context: BattleState) -> Int {
        combatant.primaryStats.controlMeterThreshold(
            baseMaxHealth: context.roster.maxHealth(for: combatant),
        )
    }

    private static func existingMeterAmount(
        at existingIndex: Int?,
        in currentEffects: [ActiveEffect],
    ) -> Int {
        guard let existingIndex,
              case let .controlMeter(_, amount, _) = currentEffects[existingIndex].effect
        else { return 0 }
        return amount
    }

    private struct ControlMeterThresholdContext {
        let keyword: Keyword
        let combatant: Combatant
        let sourceActorID: String?
        let existingIndex: Int?
        let baseThreshold: Int
    }

    // swiftlint:disable:next function_body_length
    private static func applyThresholdReached(
        _ thresholdContext: ControlMeterThresholdContext,
        currentEffects: inout [ActiveEffect],
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let keyword = thresholdContext.keyword
        let combatant = thresholdContext.combatant
        let sourceActorID = thresholdContext.sourceActorID

        updateBuildup(
            ControlMeterUpdate(
                keyword: keyword,
                newAmount: thresholdContext.baseThreshold,
                threshold: thresholdContext.baseThreshold,
                combatant: combatant,
                sourceActorID: sourceActorID,
                existingIndex: thresholdContext.existingIndex,
            ),
            currentEffects: &currentEffects,
            in: &context,
        )
        if keyword == .freeze || keyword == .stun,
           let owner = context.roster.participant(for: combatant),
           owner.isPartyMember {
            BattleCardCombatEngine.purgeControlledOwnerCards(for: owner, context: &context)
        }
        if keyword == .freeze, let sourceActorID {
            let chance = context.modifiers(for: sourceActorID).triggers.freezeExtendChancePercent
                + Double(context.modifiers(for: sourceActorID).triggers.freezeExtraActionSkips) * 0.20
            applyExtendControlChance(chance, to: combatant, in: &context)
        }
        if keyword == .stun, let sourceActorID {
            let chance = context.modifiers(for: sourceActorID).triggers.stunExtendChancePercent
                + Double(context.modifiers(for: sourceActorID).triggers.enemyStunExtraActionSkips) * 0.20
            applyExtendControlChance(chance, to: combatant, in: &context)
        }

        let actorName: String = if let sourceActorID, let source = context.roster.combatant(for: sourceActorID) {
            source.name
        } else {
            combatant.name
        }
        let abilityName = keyword.statusAlias ?? keyword.rawValue
        var events = [
            context.nextEvent(
                kind: .effect,
                effectKind: .controlTriggered,
                actorName: actorName,
                abilityName: abilityName,
                target: combatant,
                amount: 0,
                keyword: keyword,
                appliedEffectSummaries: [],
                milestone: nil,
            ),
        ]
        if keyword == .stun, combatant.id == context.roster.enemy.id {
            events.append(contentsOf: CombatTriggerEngine.afterEnemyStunned(in: &context))
        }
        events.append(contentsOf: BoonCombatEngine.afterControl(
            keyword,
            target: combatant,
            sourceActorID: sourceActorID,
            in: &context,
        ))
        if keyword == .freeze,
           combatant.role == .enemy,
           let sourceActorID,
           let source = context.roster.combatant(for: sourceActorID),
           context.modifiers(for: sourceActorID).triggers.onEnemyFrozenGainBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                context.modifiers(for: sourceActorID).triggers.onEnemyFrozenGainBlock,
                to: source.combatant,
                source: source.combatant,
                abilityName: "Glacial Barrier",
            ))
        }
        if keyword == .freeze,
           combatant.role == .enemy,
           let sourceActorID,
           let source = context.roster.combatant(for: sourceActorID),
           context.modifiers(for: sourceActorID).triggers.onFreezeEnemyGainManaEqualBlock {
            let owner = source.combatant
            let currentBlock = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: owner))
            if currentBlock > 0 {
                events.append(contentsOf: context.restoreManaEmitting(
                    currentBlock,
                    to: owner,
                    abilityName: "Rimeheart",
                ))
            }
        }
        if keyword == .stun,
           combatant.role == .enemy,
           let sourceActorID,
           context.modifiers(for: sourceActorID).triggers.onStunEnemyApplyBurn > 0,
           context.roster.health(for: combatant) > 0 {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .burn,
                potency: context.modifiers(for: sourceActorID).triggers.onStunEnemyApplyBurn,
                to: combatant,
                sourceActorID: sourceActorID,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
            ))
        }
        return events
    }

    private static func applyExtendControlChance(
        _ chance: Double,
        to combatant: Combatant,
        in context: inout BattleState,
    ) {
        guard chance > 0 else { return }
        guard BattleChance.succeeds(probability: min(1, chance), using: &context.rng) else { return }
        context.additionalControlSkipsByCombatantID[combatant.id, default: 0] += 1
        guard chance > 1 else { return }
        let additional = Int(chance - 1)
        let fractional = chance - Double(Int(chance))
        if additional > 0 {
            context.additionalControlSkipsByCombatantID[combatant.id, default: 0] += additional
        }
        if fractional > 0,
           BattleChance.succeeds(probability: fractional, using: &context.rng) {
            context.additionalControlSkipsByCombatantID[combatant.id, default: 0] += 1
        }
    }

    private struct ControlMeterUpdate {
        let keyword: Keyword
        let newAmount: Int
        let threshold: Int
        let combatant: Combatant
        let sourceActorID: String?
        let existingIndex: Int?
    }

    private static func updateBuildup(
        _ update: ControlMeterUpdate,
        currentEffects: inout [ActiveEffect],
        in context: inout BattleState,
    ) {
        let buildup = Effect.controlMeter(update.keyword, update.newAmount, update.threshold)
        if let existingIndex = update.existingIndex {
            currentEffects[existingIndex] = ActiveEffect(
                id: currentEffects[existingIndex].id,
                effect: buildup,
                remainingTurns: currentEffects[existingIndex].remainingTurns,
                sourceActorID: currentEffects[existingIndex].sourceActorID,
            )
        } else {
            currentEffects.append(
                ActiveEffect(
                    id: context.consumeNextEffectID(),
                    effect: buildup,
                    remainingTurns: 0,
                    sourceActorID: update.sourceActorID,
                ),
            )
        }
        context.roster.setActiveEffects(currentEffects, for: update.combatant)
    }
}
