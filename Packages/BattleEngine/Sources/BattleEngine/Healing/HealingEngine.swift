import Foundation
import TrinketContent
import TrinketCore

package enum HealingEngine {
    static func resolveHeal(_ request: HealRequest, in context: inout BattleState) async -> CombatOutcome {
        await CombatExecutor.suspend()
        return await resolveHealing(request, in: &context).combatOutcome
    }

    static func resolveHealing(
        _ request: HealRequest,
        in context: inout BattleState,
    ) async -> HealingResult {
        // Flawless Bounty preserves Gold reactions, but none of their nested work can restore Health.
        guard request.amount > 0, context.resolution.depth(.leechOverflowGold) == 0 else { return .empty }
        let standalone = context.resolution.beginStandaloneRestoration()
        defer {
            if standalone {
                context.resolution.endStandaloneRestoration()
            }
        }
        guard context.roster.health(for: request.target) > 0 || request.revivesIfDead else { return .empty }
        if CombatTriggerEngine.frozenTargetCannotBlockOrHeal(request.target, in: context) {
            return .empty
        }
        let sourceTriggers = request.sourceActorID.map { context.modifiers(for: $0).triggers }
        var isCritical = false
        let incomingMultiplier = CombatTriggerEngine.incomingHealMultiplier(for: request.target, in: context)
        let baseAmount = incomingMultiplier > 0
            ? resolvedAmount(request, sourceTriggers: sourceTriggers, isCritical: &isCritical, in: &context) : 0
        let boostedAmount = incomingMultiplier > 0
            ? adjustedHeroHealingAmount(baseAmount, request: request, in: &context) : 0
        let amount = CombatRounding.scaled(
            boostedAmount,
            multiplier: incomingMultiplier,
        )

        let preHealth = context.roster.health(for: request.target)
        let maxHealth = context.roster.maxHealth(for: request.target)
        let restored = applyDirectRestoration(amount: amount, request: request, sourceTriggers: sourceTriggers, in: &context)

        var allocation = HealingAllocation(resolvedAmount: amount, directRestoration: restored)
        let overflow = allocation.overflow
        await applyPreLogTalentReactions(
            request: request, restored: restored, preHealth: preHealth,
            maxHealth: maxHealth, allocation: &allocation, in: &context,
        )

        appendHealLog(request: request, restored: restored, isCritical: isCritical, in: &context)
        if overflow > 0, !request.suppressTalentReactions {
            context.nextEvent(
                kind: .effect(.overheal),
                source: context.eventSource(actorID: request.sourceActorID, fallback: request.target),
                abilityName: "",
                target: request.target,
                amount: overflow,
                keyword: .health,
                isCritical: isCritical,
                origin: request.isHoTTick ? .periodic : (request.isDirectCardHeal ? .direct : .automatic),
            )
        }
        if !request.suppressTalentReactions {
            await applyRestoredReactions(restored: restored, request: request, sourceTriggers: sourceTriggers, in: &context)
            await applyHeroHealingTalents(request: request, restored: restored, sourceTriggers: sourceTriggers, in: &context)
        }

        return HealingResult(
            allocation: allocation,
            isLeech: request.origin == .leech, isCritical: isCritical,
        )
    }

    private static func applyPreLogTalentReactions(
        request: HealRequest,
        restored: Int,
        preHealth: Int,
        maxHealth: Int,
        allocation: inout HealingAllocation,
        in context: inout BattleState,
    ) async {
        guard !request.suppressTalentReactions else { return }
        let sourceTriggers = request.sourceActorID.map { context.modifiers(for: $0).triggers }
        let targetTriggers = context.modifiers(for: request.target.id).triggers
        applyFullHealthBonus(
            preHealth: preHealth, maxHealth: maxHealth,
            request: request, targetTriggers: targetTriggers, in: &context,
        )
        let overflow = allocation.overflow
        prepareBurnAfterOverheal(overflow: overflow, target: request.target, triggers: targetTriggers, in: &context)
        applyShelterSeed(
            preHealth: preHealth, maxHealth: maxHealth, restored: restored,
            request: request, sourceTriggers: sourceTriggers, in: &context,
        )
        let cardTransfer = await transferOverhealToAlly(overflow, request: request, in: &context)
        allocation.allocate(cardTransfer.healthRestored, to: .transfer)

        await applyCleanSlate(overflow: overflow, request: request, in: &context)
        await applyOverhealConversion(
            allocation: &allocation, request: request,
            sourceTriggers: sourceTriggers, targetTriggers: targetTriggers, in: &context,
        )
        await applyOnHealGrants(restored: restored, request: request, sourceTriggers: sourceTriggers, in: &context)
    }

    private static func applyDirectRestoration(
        amount: Int,
        request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) -> Int {
        var restored = 0
        context.roster.mutateRuntime(for: request.target) { restored = $0.heal(amount) }
        if request.isDirectCardHeal, sourceTriggers?.livingArchive == true,
           let sourceActorID = request.sourceActorID, restored > 0 {
            let echoAmount = CombatRounding.scaled(restored, multiplier: 0.5)
            if echoAmount > 0 {
                let echo = HealingEcho(amount: echoAmount, sourceActorID: sourceActorID)
                context.roster.mutateRuntime(for: request.target) { $0.talents.pending.healingEchoes.append(echo) }
            }
        }
        return restored
    }

    private static func applyCleanSlate(
        overflow: Int,
        request: HealRequest,
        in context: inout BattleState,
    ) async {
        if overflow > 0,
           let srcID = request.sourceActorID,
           let src = context.roster.combatant(for: srcID),
           src.role != .enemy,
           request.target.role != .enemy,
           CombatTriggerEngine.hasLivingPartyTrigger(\.cleanSlate, in: context),
           context.resolution.depth(.talentReaction) == 0 {
            await CombatTriggerEngine.performRandomCleanses(
                source: src.combatant,
                target: request.target,
                count: 1,
                abilityName: "Clean Slate",
                in: &context,
            )
        }
    }

    private static func applyOnHealGrants(
        restored: Int,
        request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) async {
        guard restored > 0, let sourceTriggers,
              let sourceActorID = request.sourceActorID,
              context.roster.combatant(for: sourceActorID)?.isAlive == true,
              context.roster.health(for: request.target) > 0 else { return }

        if sourceTriggers.onHealGrantBlock > 0,
           let sourceID = request.sourceActorID, let source = context.roster.combatant(for: sourceID) {
            let abilityName = context.modifiers(for: sourceID).triggerAbilityName(.onHealGrantBlock, fallback: "Warded Roost")
            context.applyBlockGain(sourceTriggers.onHealGrantBlock, to: request.target, source: source.combatant, abilityName: abilityName)
        }
        if sourceTriggers.onHealCleanseTargetChance > 0,
           let sourceID = request.sourceActorID, let source = context.roster.combatant(for: sourceID),
           BattleChance.succeeds(probability: sourceTriggers.onHealCleanseTargetChance, using: &context.rng) {
            let abilityName = context.modifiers(for: sourceID).triggerAbilityName(
                .onHealCleanseTargetChance,
                fallback: "Sanctified Scroll",
            )
            await CombatTriggerEngine.performRandomCleanses(
                source: source.combatant,
                target: request.target,
                count: 1,
                abilityName: abilityName,
                in: &context,
            )
        }
        guard context.roster.combatant(for: sourceActorID)?.isAlive == true,
              context.roster.health(for: request.target) > 0 else { return }
        if sourceTriggers.healOverTimeOnHealAmount > 0,
           sourceTriggers.healOverTimeOnHealTurns > 0,
           !request.isHoTTick, let sourceActorID = request.sourceActorID {
            context.roster.mutateRuntime(for: request.target) {
                $0.talents.timed.lingeringBlessing = LingeringBlessing(
                    amount: sourceTriggers.healOverTimeOnHealAmount,
                    sourceActorID: sourceActorID,
                    turnsRemaining: max($0.talents.timed.lingeringBlessing?.turnsRemaining ?? 0, sourceTriggers.healOverTimeOnHealTurns),
                )
            }
        }
        if let sourceActorID = request.sourceActorID,
           sourceTriggers.onHealRestoreCasterMana > 0,
           let caster = context.roster.combatant(for: sourceActorID),
           caster.id != request.target.id {
            await context.restoreManaEmitting(sourceTriggers.onHealRestoreCasterMana, to: caster.combatant, abilityName: "Font of Magic")
        }
    }

    private static func appendHealLog(
        request: HealRequest,
        restored: Int,
        isCritical: Bool,
        in context: inout BattleState,
    ) {
        switch request.logAs {
        case .silent:
            break
        case let .instantHeal(source, abilityID, abilityName, keyword):
            context.nextEvent(
                kind: .effect(.instantHeal),
                source: source,
                abilityID: abilityID,
                abilityName: abilityName,
                target: request.target,
                amount: restored,
                keyword: keyword,
                isCritical: isCritical,
                origin: request.isDirectCardHeal ? .direct : .automatic,
            )
        }
    }

    private static func applyRestoredReactions(
        restored: Int,
        request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) async {
        guard restored > 0 else { return }
        CombatTriggerEngine.afterHealthRestored(restored, to: request.target, in: &context)
        if let sourceTriggers, sourceTriggers.onHealDealHoly > 0,
           let sourceID = request.sourceActorID,
           let source = context.roster.combatant(for: sourceID), source.isAlive,
           source.role != .enemy, request.target.role != .enemy, context.roster.enemy.isAlive {
            _ = await context.dealReactionDamage(sourceTriggers.onHealDealHoly, to: context.enemy, keyword: .holy, sourceActorID: sourceID)
        }
        // Loyal Companion: healing the Companion draws a Companion card once per turn.
        if request.target.id == context.roster.companion.id,
           context.roster.companion.isAlive,
           let sourceID = request.sourceActorID,
           let source = context.roster.combatant(for: sourceID),
           source.isAlive, source.role != .enemy,
           context.modifiers(for: sourceID).triggers.healCompanionDrawsCompanionCard,
           context.resolution.claim(
               .heroTalent(.loyalCompanion),
               actorID: sourceID,
               cadence: .turn(context.turnCount),
           ) {
            CombatTriggerEngine.drawCards(
                1,
                for: .companion,
                actor: source.combatant,
                abilityName: CombatTriggerEngine.triggerAbilityName(
                    .healCompanionDrawsCompanionCard,
                    for: source.combatant,
                    fallback: "Loyal Companion",
                    in: context,
                ),
                in: &context,
            )
        }
    }

    private static func resolvedAmount(
        _ request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        isCritical: inout Bool,
        in context: inout BattleState,
    ) -> Int {
        if request.amountBasis == .resolved {
            return max(0, request.amount)
        }
        let bonus = request.sourceActorID.map { context.modifiers(for: $0).healthRestoredBonus } ?? 0
        let percent = request.sourceActorID.map { context.modifiers(for: $0).healthRestoredPercent } ?? 0
        var amount = CombatRounding.scaled(
            SaturatedArithmetic.saturatingAdd(request.amount, bonus), multiplier: 1 + percent,
        )
        if request.origin != .leech, let sourceActorID = request.sourceActorID, !request.skipFightPacing {
            amount = context.paced(amount, sourceActorID: sourceActorID)
        }

        isCritical = rollRestorationCritical(for: request, amount: &amount, in: &context)

        if let sourceTriggers,
           sourceTriggers.healingBelowHealthPercentThreshold > 0,
           context.roster.maxHealth(for: request.target) > 0,
           Double(context.roster.health(for: request.target)) / Double(context.roster.maxHealth(for: request.target))
           < sourceTriggers.healingBelowHealthPercentThreshold {
            amount = CombatRounding.scaled(amount, multiplier: sourceTriggers.healingBelowHealthPercentMultiplier)
        }

        return max(0, amount)
    }

    static func resolveHealingEchoes(in context: inout BattleState) async {
        for owner in BattleParticipant.party {
            guard !context.isBattleOver else { break }
            let target = context.roster[owner].combatant
            let echoes = context.roster[owner].talents.pending.healingEchoes
            guard !echoes.isEmpty else { continue }
            context.roster.mutateRuntime(for: target) { $0.talents.pending.healingEchoes.removeAll() }
            for echo in echoes {
                guard !context.isBattleOver else { break }
                guard let source = context.roster.combatant(for: echo.sourceActorID) else { continue }
                var request = HealRequest(
                    amount: echo.amount, target: target, sourceActorID: source.id,
                    origin: .restoration(.health), logAs: .instantHeal(
                        source: .init(source),
                        abilityName: "Living Archive",
                        keyword: .health,
                    ),
                )
                request.amountBasis = .resolved
                _ = await resolveHeal(request, in: &context)
            }
        }
    }

    private static func rollRestorationCritical(
        for request: HealRequest,
        amount: inout Int,
        in context: inout BattleState,
    ) -> Bool {
        guard amount > 0,
              let sourceActorID = request.sourceActorID,
              context.roster.combatant(for: sourceActorID) != nil
        else { return false }

        guard let critKeyword = request.origin.criticalKeyword else { return false }
        guard critKeyword.allowsCriticalHits else { return false }

        guard CriticalChanceEngine.rollSucceeds(
            actorID: sourceActorID,
            defender: request.target,
            usePartyMaximum: context.modifiers(for: sourceActorID).triggers.contagiousJoy,
            in: &context,
        )
        else { return false }

        amount = SaturatedArithmetic.saturatingMul(amount, 2)
        return true
    }
}
