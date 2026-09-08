import Foundation
import TrinketContent
import TrinketCore

package enum HealingEngine {
    // swiftlint:disable:next function_body_length - healing resolution is one atomic pipeline
    static func resolveHeal(
        _ request: HealRequest,
        in context: inout BattleState,
    ) -> CombatOutcome {
        guard context.roster.health(for: request.target) > 0 || request.revivesIfDead else { return .empty }
        if CombatTriggerEngine.frozenTargetCannotBlockOrHeal(request.target, in: context) {
            return .empty
        }
        let sourceTriggers = request.sourceActorID.map { context.modifiers(for: $0).triggers }
        var flags: Set<CombatFlag> = []
        let amount = resolvedAmount(request, sourceTriggers: sourceTriggers, flags: &flags, in: &context)
        if request.isDirectCardHeal, sourceTriggers?.livingArchive == true,
           let sourceActorID = request.sourceActorID, amount > 0 {
            let echo = HealingEcho(amount: CombatRounding.scaled(amount, multiplier: 0.5), sourceActorID: sourceActorID)
            context.roster.mutateRuntime(for: request.target) { $0.healingEchoes.append(echo) }
        }

        let preHealth = context.roster.health(for: request.target)
        let maxHealth = context.roster.maxHealth(for: request.target)
        var restored = 0
        context.roster.mutateRuntime(for: request.target) { restored = $0.heal(amount) }

        var events: [ActionEvent] = []
        let targetTriggers = context.modifiers(for: request.target.id).triggers

        if targetTriggers.nextAttackBonusOnFullHealth > 0,
           preHealth < maxHealth,
           context.roster.health(for: request.target) >= maxHealth {
            context.roster.mutateRuntime(for: request.target) {
                $0.pendingAttackBonusOnFullHealth += targetTriggers.nextAttackBonusOnFullHealth
            }
        }

        let overflow = max(0, amount - max(0, maxHealth - preHealth))
        if restored > 0, preHealth * 2 < maxHealth, request.target.role != .enemy,
           sourceTriggers?.shelterSeed == true, let sourceID = request.sourceActorID,
           let source = context.roster.combatant(for: sourceID), source.isAlive {
            events.append(contentsOf: CombatTriggerEngine.heroTalentThorns(
                to: request.target, source: source.combatant, amount: restored, name: "Shelter Seed", in: &context,
            ))
        }
        events.append(contentsOf: CombatTriggerEngine.afterHeroCardHeal(
            request: request, restored: restored, overflow: overflow, in: &context,
        ))
        if overflow > 0,
           let srcID = request.sourceActorID,
           let src = context.roster.combatant(for: srcID),
           src.role != .enemy,
           request.target.role != .enemy,
           CombatTriggerEngine.livingPartyTriggers(in: context).cleanSlate,
           context.claimTurnGuard(.cleanSlate, actorID: srcID) {
            events.append(contentsOf: CombatTriggerEngine.performRandomCleanses(
                source: src.combatant,
                target: request.target,
                count: 1,
                abilityName: "Clean Slate",
                in: &context,
            ))
        }
        events.append(contentsOf: applyOverhealConversion(
            overflow: overflow,
            request: request,
            sourceTriggers: sourceTriggers,
            targetTriggers: targetTriggers,
            in: &context,
        ))

        if let sourceTriggers, sourceTriggers.onHealGrantBlock > 0, restored > 0,
           let sourceID = request.sourceActorID, let source = context.roster.combatant(for: sourceID) {
            let abilityName = context.modifiers(for: sourceID).triggerAbilityName("onHealGrantBlock", fallback: "Warded Roost")
            events.append(contentsOf: context.applyBlock(
                sourceTriggers.onHealGrantBlock,
                to: request.target,
                source: source.combatant,
                abilityName: abilityName,
            ))
        }
        if restored > 0, let sourceTriggers, sourceTriggers.onHealCleanseTargetChance > 0,
           let sourceID = request.sourceActorID, let source = context.roster.combatant(for: sourceID),
           BattleChance.succeeds(probability: sourceTriggers.onHealCleanseTargetChance, using: &context.rng) {
            let abilityName = context.modifiers(for: sourceID).triggerAbilityName(
                "onHealCleanseTargetChance",
                fallback: "Sanctified Scroll",
            )
            events.append(contentsOf: CombatTriggerEngine.performRandomCleanses(
                source: source.combatant,
                target: request.target,
                count: 1,
                abilityName: abilityName,
                in: &context,
            ))
        }
        if restored > 0, let sourceTriggers,
           sourceTriggers.healOverTimeOnHealAmount > 0,
           sourceTriggers.healOverTimeOnHealTurns > 0,
           !request.isHoTTick {
            context.roster.mutateRuntime(for: request.target) {
                $0.healOverTimeAmount = sourceTriggers.healOverTimeOnHealAmount
                $0.healOverTimeTurnsRemaining = max(
                    $0.healOverTimeTurnsRemaining,
                    sourceTriggers.healOverTimeOnHealTurns,
                )
            }
        }
        if let sourceActorID = request.sourceActorID, let sourceTriggers,
           sourceTriggers.onHealRestoreCasterMana > 0, restored > 0,
           let caster = context.roster.combatant(for: sourceActorID),
           caster.id != request.target.id {
            events.append(contentsOf: context.restoreManaEmitting(
                sourceTriggers.onHealRestoreCasterMana,
                to: caster.combatant,
                abilityName: "Font of Magic",
            ))
        }

        switch request.logAs {
        case .silent, .leech:
            break
        case let .instantHeal(actorName, abilityName, keyword):
            events.append(
                context.nextEvent(
                    kind: .effect,
                    effectKind: .instantHeal,
                    actorName: actorName,
                    abilityName: abilityName,
                    target: request.target,
                    amount: restored,
                    keyword: keyword,
                    isCritical: flags.contains(.critical),
                ),
            )
        }
        if restored > 0 {
            events.append(contentsOf: CombatTriggerEngine.afterHealthRestored(
                restored,
                to: request.target,
                in: &context,
            ))
        }

        return CombatOutcome(healthDelta: restored, events: events, flags: flags)
    }

    private static func resolvedAmount(
        _ request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        flags: inout Set<CombatFlag>,
        in context: inout BattleState,
    ) -> Int {
        if request.usesResolvedHealing {
            return max(0, request.amount)
        }
        let bonus = request.sourceActorID.map { context.modifiers(for: $0).healthRestoredBonus } ?? 0
        var amount = request.amount + bonus
        amount = CombatRounding.scaled(
            amount,
            multiplier: CombatTriggerEngine.incomingHealMultiplier(for: request.target, in: context),
        )
        if request.logAs != .leech, let sourceActorID = request.sourceActorID, !request.skipFightPacing {
            amount = context.paced(amount, sourceActorID: sourceActorID)
        }

        if let crit = rollRestorationCritical(for: request, amount: &amount, in: &context) {
            flags.insert(crit)
        }

        if let sourceTriggers,
           sourceTriggers.healingBelowHealthPercentThreshold > 0,
           context.roster.maxHealth(for: request.target) > 0,
           Double(context.roster.health(for: request.target)) / Double(context.roster.maxHealth(for: request.target))
           < sourceTriggers.healingBelowHealthPercentThreshold {
            amount = CombatRounding.scaled(amount, multiplier: sourceTriggers.healingBelowHealthPercentMultiplier)
        }

        amount += CombatTriggerEngine.heroCardHealingBonus(request: request, amount: amount, in: &context)

        return max(0, amount)
    }

    static func resolveHealingEchoes(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            let target = context.roster[owner].combatant
            let echoes = context.roster[owner].healingEchoes
            context.roster.mutateRuntime(for: target) { $0.healingEchoes.removeAll() }
            for echo in echoes {
                guard let source = context.roster.combatant(for: echo.sourceActorID) else { continue }
                var request = HealRequest(
                    amount: echo.amount, target: target, sourceActorID: source.id,
                    logAs: .instantHeal(actorName: source.name, abilityName: "Living Archive", keyword: .health),
                )
                request.usesResolvedHealing = true
                events.append(contentsOf: resolveHeal(request, in: &context).events)
            }
        }
        return events
    }

    private static func rollRestorationCritical(
        for request: HealRequest,
        amount: inout Int,
        in context: inout BattleState,
    ) -> CombatFlag? {
        guard amount > 0,
              let sourceActorID = request.sourceActorID,
              context.roster.combatant(for: sourceActorID) != nil
        else { return nil }

        let critKeyword: Keyword
        switch request.logAs {
        case let .instantHeal(_, _, keyword):
            critKeyword = keyword
        case .leech:
            critKeyword = .leech
        case .silent:
            return nil
        }
        guard critKeyword.allowsCriticalHits else { return nil }

        guard CriticalChanceEngine.rollSucceeds(
            keyword: critKeyword,
            actorID: sourceActorID,
            defender: request.target,
            usePartyMaximum: context.modifiers(for: sourceActorID).triggers.contagiousJoy,
            in: &context,
        )
        else { return nil }

        amount *= 2
        return .critical
    }

    private static func applyOverhealConversion(
        overflow: Int,
        request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        targetTriggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard overflow > 0 else { return [] }
        var events = applyLeechOverhealing(overflow: overflow, request: request, sourceTriggers: sourceTriggers, in: &context)
        if sourceTriggers?.wishspring == true {
            events.append(contentsOf: context.restoreManaEmitting(
                CombatRounding.scaled(overflow, multiplier: 0.5), to: request.target,
                abilityName: "Wishspring",
                actorName: request.sourceActorID.flatMap { context.roster.combatant(for: $0)?.name },
            ))
        }
        let conversion = overhealConversionTriggers(source: sourceTriggers, target: targetTriggers, request: request)
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
                abilityName: "Barrier Blessing",
            ))
        } else if !conversion.overhealConvertsToMaxHealth, conversion.overhealShieldCap > 0 {
            let shield = min(overflowRemaining, conversion.overhealShieldCap)
            events.append(contentsOf: context.applyBlock(
                shield,
                to: request.target,
                source: request.target,
                abilityName: "Aether Shield",
            ))
        }
        return events
    }

    private static func applyLeechOverhealing(
        overflow: Int,
        request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if request.logAs == .leech, sourceTriggers?.marrowmend == true,
           request.sourceActorID == request.target.id {
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: request.target))
            if block < 6 {
                events.append(contentsOf: context.applyBlock(
                    min(overflow, 6 - block), to: request.target, source: request.target,
                    abilityName: "Marrowmend", applyOutgoingAdjustment: false,
                ))
            }
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
        target: CombatTraitTriggers,
        request: HealRequest,
    ) -> CombatTraitTriggers {
        let isSelfHeal = request.sourceActorID == request.target.id
        if isSelfHeal {
            if let source,
               source.overhealConvertsToBlock
               || source.overhealConvertsToMaxHealth
               || source.overhealShieldCap > 0 {
                return source
            }
            return target
        }
        if target.overhealConvertsToBlock
            || target.overhealConvertsToMaxHealth
            || target.overhealShieldCap > 0 {
            return target
        }
        if let source {
            return source
        }
        return target
    }
}
