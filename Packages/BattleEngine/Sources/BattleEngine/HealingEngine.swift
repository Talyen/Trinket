import Foundation
import TrinketContent
import TrinketCore

package enum HealingEngine {
    static func resolveHeal(_ request: HealRequest, in context: inout BattleState) -> CombatOutcome {
        resolveHealing(request, in: &context).combatOutcome
    }

    // swiftlint:disable:next function_body_length - healing resolution is one atomic pipeline
    static func resolveHealing(
        _ request: HealRequest,
        in context: inout BattleState,
    ) -> HealingResult {
        guard context.roster.health(for: request.target) > 0 || request.revivesIfDead else { return .empty }
        if CombatTriggerEngine.frozenTargetCannotBlockOrHeal(request.target, in: context) {
            return .empty
        }
        let sourceTriggers = request.sourceActorID.map { context.modifiers(for: $0).triggers }
        var flags: Set<CombatFlag> = []
        let amount = resolvedAmount(request, sourceTriggers: sourceTriggers, flags: &flags, in: &context)

        let preHealth = context.roster.health(for: request.target)
        let maxHealth = context.roster.maxHealth(for: request.target)
        var restored = 0
        context.roster.mutateRuntime(for: request.target) { restored = $0.heal(amount) }
        if request.isDirectCardHeal, sourceTriggers?.livingArchive == true,
           let sourceActorID = request.sourceActorID, restored > 0 {
            let echoAmount = CombatRounding.scaled(restored, multiplier: 0.5)
            if echoAmount > 0 {
                let echo = HealingEcho(amount: echoAmount, sourceActorID: sourceActorID)
                context.roster.mutateRuntime(for: request.target) { $0.healingEchoes.append(echo) }
            }
        }

        var events: [ActionEvent] = []
        let targetTriggers = context.modifiers(for: request.target.id).triggers

        if targetTriggers.nextAttackBonusOnFullHealth > 0,
           preHealth < maxHealth,
           context.roster.health(for: request.target) >= maxHealth {
            context.roster.mutateRuntime(for: request.target) {
                $0.pendingAttackBonusOnFullHealth += targetTriggers.nextAttackBonusOnFullHealth
            }
        }

        var allocation = HealingAllocation(resolvedAmount: amount, directRestoration: restored)
        let overflow = allocation.overflow
        if restored > 0, preHealth * 2 < maxHealth, request.target.role != .enemy,
           sourceTriggers?.shelterSeed == true, let sourceID = request.sourceActorID,
           let source = context.roster.combatant(for: sourceID), source.isAlive {
            events.append(contentsOf: CombatTriggerEngine.heroTalentThorns(
                to: request.target, source: source.combatant, amount: restored, name: "Shelter Seed", in: &context,
            ))
        }
        let cardTransfer = transferCardOverheal(overflow, request: request, in: &context)
        allocation.allocate(cardTransfer.healthRestored, to: .transfer)
        events.append(contentsOf: cardTransfer.events)
        events.append(contentsOf: CombatTriggerEngine.afterHeroCardHeal(
            request: request, restored: restored, in: &context,
        ))
        if overflow > 0,
           let srcID = request.sourceActorID,
           let src = context.roster.combatant(for: srcID),
           src.role != .enemy,
           request.target.role != .enemy,
           CombatTriggerEngine.hasLivingPartyTrigger(\.cleanSlate, in: context),
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
            allocation: &allocation,
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
           !request.isHoTTick, let sourceActorID = request.sourceActorID {
            context.roster.mutateRuntime(for: request.target) {
                $0.lingeringBlessing = LingeringBlessing(
                    amount: sourceTriggers.healOverTimeOnHealAmount,
                    sourceActorID: sourceActorID,
                    turnsRemaining: max($0.lingeringBlessing?.turnsRemaining ?? 0, sourceTriggers.healOverTimeOnHealTurns),
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
        case .silent:
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
            if let sourceTriggers, sourceTriggers.onHealDealHoly > 0,
               let sourceID = request.sourceActorID,
               let source = context.roster.combatant(for: sourceID), source.isAlive,
               source.role != .enemy, request.target.role != .enemy, context.roster.enemy.isAlive {
                events.append(contentsOf: context.resolveDamage(DamageRequest(
                    amount: sourceTriggers.onHealDealHoly, target: context.enemy,
                    keyword: .holy, sourceActorID: sourceID, options: .reaction(),
                )).events)
            }
        }

        return HealingResult(
            allocation: allocation,
            isLeech: request.origin == .leech, isCritical: flags.contains(.critical), events: events,
        )
    }

    private static func resolvedAmount(
        _ request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        flags: inout Set<CombatFlag>,
        in context: inout BattleState,
    ) -> Int {
        if request.amountBasis == .resolved {
            return max(0, request.amount)
        }
        let bonus = request.sourceActorID.map { context.modifiers(for: $0).healthRestoredBonus } ?? 0
        var amount = request.amount + bonus
        amount = CombatRounding.scaled(
            amount,
            multiplier: CombatTriggerEngine.incomingHealMultiplier(for: request.target, in: context),
        )
        if request.origin != .leech, let sourceActorID = request.sourceActorID, !request.skipFightPacing {
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
                    origin: .restoration(.health), logAs: .instantHeal(
                        actorName: source.name,
                        abilityName: "Living Archive",
                        keyword: .health,
                    ),
                )
                request.amountBasis = .resolved
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

        guard let critKeyword = request.origin.criticalKeyword else { return nil }
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
}
