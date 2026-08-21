import Foundation
import TrinketContent
import TrinketCore

/// Healing and leech rules.
package enum HealingEngine {
    // swiftlint:disable:next function_body_length
    static func resolveHeal(
        _ request: HealRequest,
        in context: inout BattleState
    ) -> CombatOutcome {
        guard context.roster.health(for: request.target) > 0 || request.revivesIfDead else { return .empty }
        if CombatTriggerEngine.frozenTargetCannotBlockOrHeal(request.target, in: context) {
            return .empty
        }
        let sourceTriggers = request.sourceActorID.map { context.modifiers(for: $0).triggers }
        let bonus = request.sourceActorID.map { context.modifiers(for: $0).healthRestoredBonus } ?? 0
        var amount = request.amount + bonus
        amount = CombatRounding.scaled(
            amount,
            multiplier: CombatTriggerEngine.incomingHealMultiplier(for: request.target, in: context)
        )
        if request.logAs != .leech, let sourceActorID = request.sourceActorID, !request.skipFightPacing {
            amount = context.paced(amount, sourceActorID: sourceActorID)
        }
        var flags: Set<CombatFlag> = []

        if let crit = rollRestorationCritical(for: request, amount: &amount, in: &context) {
            flags.insert(crit)
        }

        // Emergency Mend: healing allies below the threshold restores double.
        if let sourceTriggers,
           sourceTriggers.healingBelowHealthPercentThreshold > 0,
           context.roster.maxHealth(for: request.target) > 0,
           Double(context.roster.health(for: request.target)) / Double(context.roster.maxHealth(for: request.target))
           < sourceTriggers.healingBelowHealthPercentThreshold {
            amount = CombatRounding.scaled(amount, multiplier: sourceTriggers.healingBelowHealthPercentMultiplier)
        }

        let preHealth = context.roster.health(for: request.target)
        let maxHealth = context.roster.maxHealth(for: request.target)
        var restored = 0
        context.roster.mutateRuntime(for: request.target) { restored = $0.heal(amount) }

        var events: [ActionEvent] = []
        let targetTriggers = context.modifiers(for: request.target.id).triggers

        // Sanguine Overflow: reaching full Health empowers the owner's next attack.
        if targetTriggers.nextAttackBonusOnFullHealth > 0,
           preHealth < maxHealth,
           context.roster.health(for: request.target) >= maxHealth {
            context.roster.mutateRuntime(for: request.target) {
                $0.pendingAttackBonusOnFullHealth += targetTriggers.nextAttackBonusOnFullHealth
            }
        }

        // Talent overheal routing: prefer the healer's conversion talents so
        // companion overheal (Vital Infusion / Ashen Vitality / Barrier Blessing) applies
        // to the ally they healed.
        let overflow = max(0, amount - max(0, maxHealth - preHealth))
        events.append(contentsOf: applyOverhealConversion(
            overflow: overflow,
            request: request,
            sourceTriggers: sourceTriggers,
            targetTriggers: targetTriggers,
            in: &context
        ))

        // Warded Roost / Protective Bloom: healing an ally grants them Block.
        if let sourceTriggers, sourceTriggers.onHealGrantBlock > 0, restored > 0 {
            let abilityName = request.sourceActorID.map {
                context.modifiers(for: $0).triggerAbilityName("onHealGrantBlock", fallback: "Warded Roost")
            } ?? "Warded Roost"
            events.append(contentsOf: context.applyBlock(
                sourceTriggers.onHealGrantBlock,
                to: request.target,
                source: request.target,
                abilityName: abilityName
            ))
        }
        // Lingering Blessing: successful heals apply a short heal-over-time.
        if restored > 0, let sourceTriggers,
           sourceTriggers.healOverTimeOnHealAmount > 0,
           sourceTriggers.healOverTimeOnHealTurns > 0,
           !request.isLingeringBlessingTick {
            context.roster.mutateRuntime(for: request.target) {
                $0.healOverTimeAmount = sourceTriggers.healOverTimeOnHealAmount
                $0.healOverTimeTurnsRemaining = max(
                    $0.healOverTimeTurnsRemaining,
                    sourceTriggers.healOverTimeOnHealTurns
                )
            }
        }
        // Font of Magic: healing an ally restores Mana to the caster.
        if let sourceActorID = request.sourceActorID, let sourceTriggers,
           sourceTriggers.onHealRestoreCasterMana > 0, restored > 0,
           let caster = context.roster.combatant(for: sourceActorID),
           caster.id != request.target.id {
            let restoredMana = context.restoreMana(sourceTriggers.onHealRestoreCasterMana, to: caster.combatant)
            if restoredMana > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .resourceGain,
                    actorName: caster.name,
                    abilityName: "Font of Magic",
                    target: caster.combatant,
                    amount: restoredMana,
                    keyword: .mana
                ))
                events.append(contentsOf: CombatTriggerEngine.afterGainMana(by: caster.combatant, in: &context))
            }
        }

        switch request.logAs {
        case .silent, .leech:
            break
        case let .instantHeal(actorName, abilityName, keyword, _):
            events.append(
                context.nextEvent(
                    kind: .effect,
                    effectKind: .instantHeal,
                    actorName: actorName,
                    abilityName: abilityName,
                    target: request.target,
                    amount: restored,
                    keyword: keyword,
                    isCritical: flags.contains(.critical)
                )
            )
        }
        if restored > 0 {
            events.append(contentsOf: CombatTriggerEngine.afterHealthRestored(
                restored,
                to: request.target,
                in: &context
            ))
        }

        return CombatOutcome(healthDelta: restored, events: events, flags: flags)
    }

    /// Rolls Wisdom-scaled restoration crit for Health / Leech heals. Doubles the
    /// heal amount in place when it hits. Returns `.critical` when the roll succeeds.
    private static func rollRestorationCritical(
        for request: HealRequest,
        amount: inout Int,
        in context: inout BattleState
    ) -> CombatFlag? {
        guard amount > 0,
              let sourceActorID = request.sourceActorID,
              let actor = context.roster.combatant(for: sourceActorID)
        else { return nil }

        let critKeyword: Keyword
        switch request.logAs {
        case let .instantHeal(_, _, keyword, _):
            critKeyword = keyword
        case .leech:
            critKeyword = .leech
        case .silent:
            return nil
        }
        guard critKeyword.allowsCriticalHits else { return nil }

        var chance = actor.primaryStats.contestedCriticalChance(
            for: critKeyword,
            againstDefenderToughness: request.target.primaryStats.toughness
        )
        chance += context.modifiers(for: sourceActorID).triggers.criticalChanceBonus
        for active in context.roster.activeEffects(for: actor.combatant) {
            if case let .criticalChanceBonus(bonus, _) = active.effect {
                chance += bonus
            }
        }
        let cap = DamagePipeline.criticalChanceCap(for: actor.combatant)
        chance = min(cap, max(0, chance))
        guard BattleChance.succeeds(probability: chance, using: &context.rng) else { return nil }

        amount *= 2
        return .critical
    }

    private static func applyOverhealConversion(
        overflow: Int,
        request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        targetTriggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard overflow > 0 else { return [] }
        var events: [ActionEvent] = []
        let conversion = overhealConversionTriggers(source: sourceTriggers, target: targetTriggers)
        var overflowRemaining = overflow
        if conversion.overhealConvertsToMaxHealth {
            let perEvent = conversion.overhealConvertsToMaxHealthPerEvent
            var gain = perEvent > 0 ? min(overflow, perEvent) : overflow
            let cap = conversion.overhealConvertsToMaxHealthCap
            if cap > 0 {
                let already = context.roster.runtime(for: request.target)?.talentMaxHealthBonus ?? 0
                gain = min(gain, max(0, cap - already))
            }
            if gain > 0 {
                context.roster.mutateRuntime(for: request.target) { runtime in
                    runtime.talentMaxHealthBonus += gain
                    runtime.currentHealth = min(runtime.maxHealth, runtime.currentHealth + gain)
                }
            }
            overflowRemaining = overflow - gain
        }
        if conversion.overhealConvertsToBlock, overflowRemaining > 0 {
            events.append(contentsOf: context.applyBlock(
                overflowRemaining,
                to: request.target,
                source: request.target,
                abilityName: "Barrier Blessing"
            ))
        } else if !conversion.overhealConvertsToMaxHealth, conversion.overhealShieldCap > 0 {
            let shield = min(overflowRemaining, conversion.overhealShieldCap)
            events.append(contentsOf: context.applyBlock(
                shield,
                to: request.target,
                source: request.target,
                abilityName: "Aether Shield"
            ))
        }
        if request.logAs == .leech,
           let sourceActorID = request.sourceActorID,
           let source = context.roster.combatant(for: sourceActorID) {
            let bonus = context.modifiers(for: sourceActorID).triggers.leechOverhealDamageBonus
            if bonus > 0 {
                context.roster.mutateRuntime(for: source.combatant) { runtime in
                    let current = runtime.talentLeechOverhealDamageBonus
                    let allowed = max(0, 4 - current)
                    let toAdd = min(bonus, allowed)
                    if toAdd > 0 {
                        runtime.talentLeechOverhealDamageBonus += toAdd
                        runtime.permanentDamageBonus += toAdd
                    }
                }
            }
        }
        return events
    }

    private static func overhealConversionTriggers(
        source: CombatTraitTriggers?,
        target: CombatTraitTriggers
    ) -> CombatTraitTriggers {
        if let source,
           source.overhealConvertsToBlock
           || source.overhealConvertsToMaxHealth
           || source.overhealShieldCap > 0 {
            return source
        }
        return target
    }
}
