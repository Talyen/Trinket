import TrinketContent
import TrinketCore

extension HealingEngine {
    static func transferOverhealToAlly(
        _ overflow: Int, request: HealRequest, in context: inout BattleState,
    ) async -> CombatOutcome {
        guard overflow > 0, let sourceID = request.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.isAlive,
              request.target.role != .enemy else { return .empty }
        let triggers = context.modifiers(for: sourceID).triggers
        let sharedFeast = request.origin == .leech && sourceID == request.target.id
            && triggers.leechOverflowShareAlly
        let contagiousJoy = context.modifiers(for: request.target.id).triggers.excessHealthShareAlly
        guard triggers.sharedPrescription || sharedFeast || contagiousJoy else { return .empty }
        let other = request.target.role == .hero ? context.roster.companion : context.roster.hero
        let amount = min(overflow, max(0, other.maxHealth - other.currentHealth))
        guard other.isAlive, amount > 0 else { return .empty }
        var transfer = HealRequest(
            amount: amount, target: other.combatant, sourceActorID: sourceID,
            origin: .restoration(.health), logAs: .instantHeal(
                source: contagiousJoy ? .init(request.target) : .init(source),
                abilityName: contagiousJoy ? "Contagious Joy" : (sharedFeast ? "Shared Feast" : "Shared Prescription"),
                keyword: .health,
            ),
        )
        transfer.amountBasis = .resolved
        return await resolveHeal(transfer, in: &context)
    }

    static func applyOverhealConversion(
        allocation: inout HealingAllocation,
        request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        targetTriggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        let overflow = allocation.overflow
        guard overflow > 0 else { return }
        await applyLeechOverhealing(allocation: &allocation, request: request, sourceTriggers: sourceTriggers, in: &context)
        prepareFreeManaEmpowermentAfterOverheal(request: request, triggers: sourceTriggers, in: &context)
        if sourceTriggers?.wishspring == true,
           let sourceID = request.sourceActorID,
           let source = context.roster.combatant(for: sourceID), source.isAlive {
            await context.restoreManaEmitting(
                CombatRounding.scaled(overflow, multiplier: 0.5), to: request.target,
                abilityName: "Wishspring",
                source: source.combatant,
            )
        }
        applyBlockOverhealConversion(
            allocation: &allocation, request: request,
            sourceTriggers: sourceTriggers, targetTriggers: targetTriggers, in: &context,
        )
    }

    private static func providedOverhealConversion(
        request: HealRequest, sourceTriggers: CombatTraitTriggers?, targetTriggers: CombatTraitTriggers,
        in context: BattleState,
    ) -> (triggers: CombatTraitTriggers, source: Combatant) {
        let source = request.sourceActorID.flatMap { context.roster.combatant(for: $0) }
        let livingSourceTriggers = source?.isAlive == true ? sourceTriggers : nil
        var conversion = overhealConversionTriggers(source: livingSourceTriggers, target: targetTriggers, request: request)
        let hasProvidedConversion = source?.isAlive == true
            && (sourceTriggers?.providedOverhealConvertsToBlock == true
                || (sourceTriggers?.providedOverhealToBlockPercent ?? 0) > 0)
        let blockSource = hasProvidedConversion ? (source?.combatant ?? request.target) : request.target
        if source?.isAlive == true, let sourceTriggers {
            conversion.overhealConvertsToBlock = conversion.overhealConvertsToBlock
                || sourceTriggers.providedOverhealConvertsToBlock
            conversion.overhealToBlockPercent = max(
                conversion.overhealToBlockPercent, sourceTriggers.providedOverhealToBlockPercent,
            )
        }
        return (conversion, blockSource)
    }

    private static func applyBlockOverhealConversion(
        allocation: inout HealingAllocation, request: HealRequest,
        sourceTriggers: CombatTraitTriggers?, targetTriggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        let (conversion, blockSource) = providedOverhealConversion(
            request: request, sourceTriggers: sourceTriggers, targetTriggers: targetTriggers, in: context,
        )

        convertOverhealToMaximumHealth(conversion, target: request.target, allocation: &allocation, in: &context)
        if conversion.overhealConvertsToBlock, allocation.remaining > 0 {
            let gain = context.applyBlockGain(
                allocation.remaining,
                to: request.target,
                source: blockSource,
                abilityName: "Barrier Blessing",
                amountBasis: .resolved,
            )
            allocation.allocate(gain, to: .block)

        } else if !conversion.overhealConvertsToMaxHealth, conversion.overhealFirstBlockPerTurn > 0,
                  allocation.remaining > 0,
                  context.claimTurnGuard(
                      .overhealFirstBlock,
                      actorID: request.sourceActorID ?? request.target.id,
                  ) {
            context.applyBlockGain(
                conversion.overhealFirstBlockPerTurn,
                to: request.target,
                source: request.target,
                abilityName: "Aether Shield",
            )
        } else if !conversion.overhealConvertsToMaxHealth, conversion.overhealToBlockPercent > 0 {
            convertFractionalOverhealToBlock(
                allocation: &allocation,
                target: request.target,
                source: blockSource,
                percent: conversion.overhealToBlockPercent,
                in: &context,
            )
        } else if !conversion.overhealConvertsToMaxHealth, conversion.overhealShieldCap > 0 {
            let shield = min(allocation.remaining, conversion.overhealShieldCap)
            let gain = context.applyBlockGain(
                shield,
                to: request.target,
                source: request.target,
                abilityName: context.modifiers(for: request.target.id).triggerAbilityName(
                    .overhealShieldCap,
                    fallback: "Reclaimed Reagents",
                ),
            )
            allocation.allocate(min(shield, gain), to: .block)
        }
    }

    private static func prepareFreeManaEmpowermentAfterOverheal(
        request: HealRequest,
        triggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) {
        guard triggers?.excessHealthNextManaEmpowerFree == true,
              request.origin != .periodic,
              let sourceID = request.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.isAlive else { return }
        context.roster.mutateRuntime(for: source.combatant) {
            $0.talents.pending.nextManaEmpowerDiscount = max($0.talents.pending.nextManaEmpowerDiscount, 3)
        }
    }

    private static func convertFractionalOverhealToBlock(
        allocation: inout HealingAllocation,
        target: Combatant,
        source: Combatant,
        percent: Double,
        in context: inout BattleState,
    ) {
        let shield = min(allocation.remaining, CombatRounding.scaled(allocation.remaining, multiplier: percent))
        guard shield > 0 else { return }
        let gain = context.applyBlockGain(shield, to: target, source: source, abilityName: "Reclaimed Reagents", amountBasis: .resolved)
        allocation.allocate(gain, to: .block)
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
        if let runtime = context.roster.runtime(for: target) {
            gain = CombatGain.amount(gain, current: runtime.maxHealth, cap: Int.max)
        }
        gain = allocation.allocate(gain, to: .maximumHealth)
        if gain > 0 {
            context.roster.mutateRuntime(for: target) { runtime in
                runtime.talents.battle.maximumHealthBonus = SaturatedArithmetic.saturatingAdd(
                    runtime.talents.battle.maximumHealthBonus,
                    gain,
                )
                runtime.currentHealth = min(runtime.maxHealth, SaturatedArithmetic.saturatingAdd(runtime.currentHealth, gain))
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

    private static func convertLeechOverflowToMana(
        allocation: inout HealingAllocation, request: HealRequest, sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) async {
        if request.origin == .leech, sourceTriggers?.excessLeechRestoresMana == true,
           let sourceID = request.sourceActorID,
           let source = context.roster.combatant(for: sourceID), source.isAlive {
            let converted = allocation.allocate(
                CombatGain.amount(allocation.remaining, current: source.currentMana, cap: source.maxMana),
                to: .mana,
            )
            if converted > 0 {
                await context.restoreManaEmitting(converted, to: source.combatant, abilityName: "Soul Drain", isResolved: true)
            }
        }
    }

    static func applyLeechOverhealing(
        allocation: inout HealingAllocation,
        request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) async {
        guard request.origin == .leech,
              let sourceActorID = request.sourceActorID,
              context.roster.combatant(for: sourceActorID)?.isAlive == true else { return }
        let transferAmount = CombatGain.amount(
            allocation.remaining, current: context.roster.companion.currentHealth, cap: context.roster.companion.maxHealth,
        )
        if sourceTriggers?.leechOverhealTransfersToCompanion == true,
           sourceActorID == context.hero.id, request.target.id == context.hero.id,
           context.roster.companion.isAlive, transferAmount > 0 {
            var transfer = HealRequest(
                amount: transferAmount, target: context.companion, sourceActorID: sourceActorID,
                origin: .leech, logAs: .silent,
            )
            transfer.amountBasis = .resolved
            let outcome = await resolveHeal(transfer, in: &context)

            if outcome.healthRestored > 0 {
                allocation.allocate(outcome.healthRestored, to: .transfer)
                context.nextEvent(
                    kind: .effect(.leechHeal), source: .init(context.hero),
                    abilityName: "Blood Link", target: context.companion,
                    amount: outcome.healthRestored, keyword: .leech,
                )
            }
        }
        guard context.roster.combatant(for: sourceActorID)?.isAlive == true else { return }
        await convertLeechOverflowToMana(allocation: &allocation, request: request, sourceTriggers: sourceTriggers, in: &context)
        guard let source = context.roster.combatant(for: sourceActorID), source.isAlive else { return }
        if sourceTriggers?.marrowmend == true,
           sourceActorID == request.target.id,
           context.claimHeroTalent(.marrowmend, actorID: request.target.id) {
            let converted = CombatRounding.scaled(allocation.remaining, multiplier: 0.5)
            if converted > 0 {
                let gain = context.applyBlockGain(
                    converted, to: request.target, source: request.target,
                    abilityName: "Marrowmend", amountBasis: .resolved,
                )
                allocation.allocate(gain, to: .block)
            }
        }
        let bonus = context.modifiers(for: sourceActorID).triggers.leechOverhealDamageBonus
        if bonus > 0 {
            context.roster.mutateRuntime(for: source.combatant) { runtime in
                let current = runtime.talents.battle.leechOverhealDamageBonus
                let allowed = max(0, 4 - current)
                let toAdd = min(bonus, allowed)
                if toAdd > 0 {
                    runtime.talents.battle.leechOverhealDamageBonus += toAdd
                    runtime.talents.battle.damageBonus = SaturatedArithmetic.saturatingAdd(runtime.talents.battle.damageBonus, toAdd)
                }
            }
        }
    }
}
