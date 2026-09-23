import TrinketContent
import TrinketCore

extension HealingEngine {
    static func transferOverhealToAlly(
        _ overflow: Int, request: HealRequest, in context: inout BattleState,
    ) -> CombatOutcome {
        guard overflow > 0, let sourceID = request.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.isAlive,
              request.target.role != .enemy,
              context.modifiers(for: sourceID).triggers.sharedPrescription else { return .empty }
        let other = request.target.role == .hero ? context.roster.companion : context.roster.hero
        let amount = min(overflow, max(0, other.maxHealth - other.currentHealth))
        guard other.isAlive, amount > 0 else { return .empty }
        var transfer = HealRequest(
            amount: amount, target: other.combatant, sourceActorID: sourceID,
            origin: .restoration(.health), logAs: .instantHeal(
                actorName: source.name, abilityName: "Shared Prescription", keyword: .health,
            ),
        )
        transfer.amountBasis = .resolved
        return resolveHeal(transfer, in: &context)
    }

    static func applyOverhealConversion(
        allocation: inout HealingAllocation,
        request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        targetTriggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let overflow = allocation.overflow
        guard overflow > 0 else { return [] }
        var events = applyLeechOverhealing(
            allocation: &allocation, request: request, sourceTriggers: sourceTriggers, in: &context,
        )
        if sourceTriggers?.wishspring == true {
            events.append(contentsOf: context.restoreManaEmitting(
                CombatRounding.scaled(overflow, multiplier: 0.5), to: request.target,
                abilityName: "Wishspring",
                actorName: request.sourceActorID.flatMap { context.roster.combatant(for: $0)?.name },
            ))
        }
        let conversion = overhealConversionTriggers(source: sourceTriggers, target: targetTriggers, request: request)
        convertOverhealToMaximumHealth(conversion, target: request.target, allocation: &allocation, in: &context)
        if conversion.overhealConvertsToBlock, allocation.remaining > 0 {
            let converted = allocation.allocate(allocation.remaining, to: .block)
            events.append(contentsOf: context.applyBlock(
                converted,
                to: request.target,
                source: request.target,
                abilityName: "Barrier Blessing",
            ))
        } else if !conversion.overhealConvertsToMaxHealth, conversion.overhealFirstBlockPerTurn > 0,
                  allocation.remaining > 0,
                  context.claimTurnGuard(
                      .overhealFirstBlock,
                      actorID: request.sourceActorID ?? request.target.id,
                  ) {
            events.append(contentsOf: context.applyBlock(
                conversion.overhealFirstBlockPerTurn,
                to: request.target,
                source: request.target,
                abilityName: "Aether Shield",
            ))
        } else if !conversion.overhealConvertsToMaxHealth, conversion.overhealToBlockPercent > 0 {
            events.append(contentsOf: convertFractionalOverhealToBlock(
                allocation: &allocation,
                target: request.target,
                percent: conversion.overhealToBlockPercent,
                in: &context,
            ))
        } else if !conversion.overhealConvertsToMaxHealth, conversion.overhealShieldCap > 0 {
            let shield = allocation.allocate(conversion.overhealShieldCap, to: .block)
            events.append(contentsOf: context.applyBlock(
                shield,
                to: request.target,
                source: request.target,
                abilityName: context.modifiers(for: request.target.id).triggerAbilityName(
                    "overhealShieldCap",
                    fallback: "Reclaimed Reagents",
                ),
            ))
        }
        return events
    }

    private static func convertFractionalOverhealToBlock(
        allocation: inout HealingAllocation,
        target: Combatant,
        percent: Double,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let shield = allocation.allocate(
            CombatRounding.scaled(allocation.remaining, multiplier: percent),
            to: .block,
        )
        guard shield > 0 else { return [] }
        return context.applyBlock(
            shield,
            to: target,
            source: target,
            abilityName: "Reclaimed Reagents",
            amountBasis: .resolved,
        )
    }

    private static func convertOverhealToMaximumHealth(
        _ conversion: CombatTraitTriggers,
        target: Combatant,
        allocation: inout HealingAllocation,
        in context: inout BattleState,
    ) {
        guard conversion.overhealConvertsToMaxHealth else { return }
        let perEvent = conversion.overhealConvertsToMaxHealthPerEvent
        var gain = perEvent > 0 ? min(allocation.remaining, perEvent) : allocation.remaining
        let cap = conversion.overhealConvertsToMaxHealthCap
        if cap > 0 {
            let already = context.roster.runtime(for: target)?.talents.battle.maximumHealthBonus ?? 0
            gain = CombatGain.amount(gain, current: already, cap: cap)
        }
        gain = allocation.allocate(gain, to: .maximumHealth)
        if gain > 0 {
            context.roster.mutateRuntime(for: target) { runtime in
                runtime.talents.battle.maximumHealthBonus += gain
                runtime.currentHealth = min(runtime.maxHealth, runtime.currentHealth + gain)
            }
        }
    }

    private static func overhealConversionTriggers(
        source: CombatTraitTriggers?,
        target: CombatTraitTriggers,
        request: HealRequest,
    ) -> CombatTraitTriggers {
        // One overflow, one conversion: the recipient's body decides what excess
        // healing becomes, except self-heals where source and recipient coincide.
        // Callers apply only the first matching branch (Block, then
        // once-per-turn Block, then capped Block), so stacked overflow talents
        // cannot triple-spend the same excess.
        let isSelfHeal = request.sourceActorID == request.target.id
        if isSelfHeal {
            if let source,
               source.overhealConvertsToBlock
               || source.overhealConvertsToMaxHealth
               || source.overhealShieldCap > 0
               || source.overhealToBlockPercent > 0
               || source.overhealFirstBlockPerTurn > 0 {
                return source
            }
            return target
        }
        if target.overhealConvertsToBlock
            || target.overhealConvertsToMaxHealth
            || target.overhealShieldCap > 0
            || target.overhealToBlockPercent > 0
            || target.overhealFirstBlockPerTurn > 0 {
            return target
        }
        if let source {
            return source
        }
        return target
    }

    static func applyLeechOverhealing(
        allocation: inout HealingAllocation,
        request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        let transferAmount = CombatGain.amount(
            allocation.remaining, current: context.roster.companion.currentHealth, cap: context.roster.companion.maxHealth,
        )
        if request.origin == .leech, sourceTriggers?.leechOverhealTransfersToCompanion == true,
           request.sourceActorID == context.hero.id, request.target.id == context.hero.id,
           context.roster.companion.isAlive, transferAmount > 0 {
            var transfer = HealRequest(
                amount: transferAmount, target: context.companion, sourceActorID: request.sourceActorID,
                origin: .leech, logAs: .silent,
            )
            transfer.amountBasis = .resolved
            let outcome = resolveHeal(transfer, in: &context)
            events.append(contentsOf: outcome.events)
            if outcome.healthRestored > 0 {
                allocation.allocate(outcome.healthRestored, to: .transfer)
                events.append(context.nextEvent(
                    kind: .effect, effectKind: .leechHeal, actorName: context.hero.name,
                    abilityName: "Blood Link", target: context.companion,
                    amount: outcome.healthRestored, keyword: .leech,
                ))
            }
        }
        if request.origin == .leech, sourceTriggers?.marrowmend == true,
           request.sourceActorID == request.target.id {
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: request.target))
            let converted = allocation.allocate(max(0, 6 - block), to: .block)
            if converted > 0 {
                events.append(contentsOf: context.applyBlock(
                    converted, to: request.target, source: request.target,
                    abilityName: "Marrowmend", amountBasis: .resolved,
                ))
            }
        }
        if request.origin == .leech,
           let sourceActorID = request.sourceActorID,
           let source = context.roster.combatant(for: sourceActorID) {
            let bonus = context.modifiers(for: sourceActorID).triggers.leechOverhealDamageBonus
            if bonus > 0 {
                context.roster.mutateRuntime(for: source.combatant) { runtime in
                    let current = runtime.talents.battle.leechOverhealDamageBonus
                    let allowed = max(0, 4 - current)
                    let toAdd = min(bonus, allowed)
                    if toAdd > 0 {
                        runtime.talents.battle.leechOverhealDamageBonus += toAdd
                        runtime.talents.battle.damageBonus += toAdd
                    }
                }
            }
        }
        return events
    }
}
