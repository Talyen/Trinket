import TrinketContent
import TrinketCore

extension HealingEngine {
    static func transferCardOverheal(
        _ overflow: Int, request: HealRequest, in context: inout BattleState,
    ) -> CombatOutcome {
        guard overflow > 0, request.isDirectCardHeal, let sourceID = request.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.isAlive,
              context.hasHeroCard(for: sourceID), request.target.role != .enemy,
              context.modifiers(for: sourceID).triggers.masterworkMixture else { return .empty }
        let other = request.target.role == .hero ? context.roster.companion : context.roster.hero
        let amount = min(overflow, max(0, other.maxHealth - other.currentHealth))
        guard other.isAlive, amount > 0 else { return .empty }
        var transfer = HealRequest(
            amount: amount, target: other.combatant, sourceActorID: sourceID,
            origin: .restoration(.health), logAs: .instantHeal(
                actorName: source.name, abilityName: "Masterwork Mixture", keyword: .health,
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
        let isSelfHeal = request.sourceActorID == request.target.id
        if isSelfHeal {
            if let source,
               source.overhealConvertsToBlock
               || source.overhealConvertsToMaxHealth
               || source.overhealShieldCap > 0
               || source.overhealFirstBlockPerTurn > 0 {
                return source
            }
            return target
        }
        if target.overhealConvertsToBlock
            || target.overhealConvertsToMaxHealth
            || target.overhealShieldCap > 0
            || target.overhealFirstBlockPerTurn > 0 {
            return target
        }
        if let source {
            return source
        }
        return target
    }
}
