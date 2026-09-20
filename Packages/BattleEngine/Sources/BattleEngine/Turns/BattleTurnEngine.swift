import Foundation
import os
import TrinketContent
import TrinketCore

package enum BattleTurnEngine {
    private static let logger = Logger(
        subsystem: "com.ryanmcintire.Trinket",
        category: "BattleTurnEngine",
    )

    package static func consumeActionSkip(
        for actor: Combatant,
        context: inout BattleState,
    ) -> [ActionEvent] {
        var keyword: Keyword?
        var recovered = false

        context.roster.mutateRuntime(for: actor) { runtime in
            guard let index = runtime.activeEffects.firstIndex(where: \.isAwaitingActionSkip) else { return }
            var effect = runtime.activeEffects[index]
            keyword = effect.keyword
            let extraSkips = context.additionalControlSkipsByCombatantID[actor.id, default: 0]
            if extraSkips > 0 {
                context.additionalControlSkipsByCombatantID[actor.id] = extraSkips - 1
                effect.remainingTurns = 0
            } else {
                effect.remainingTurns = BattleTiming.controlStatusLingerTurns
                recovered = true
            }
            runtime.activeEffects[index] = effect
        }

        guard let keyword else {
            recordAction(for: actor, context: &context)
            return []
        }

        let event = context.nextEvent(
            kind: .effect,
            effectKind: .controlActionSkipped,
            actorName: keyword.statusAlias ?? keyword.rawValue,
            abilityName: keyword.statusAlias ?? keyword.rawValue,
            target: actor,
            amount: 0,
            keyword: keyword,
        )
        var events = [event]

        if actor.role == .enemy, keyword == .stun, recovered {
            events.append(contentsOf: CombatCheckpoint.controlRecovery(actor.id, .stun).resolve([
                { CombatTriggerEngine.afterEnemyStunRecover(in: &$0) },
            ], in: &context))
        }

        recordAction(for: actor, context: &context)
        return events
    }

    package static func performAction(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        origin: DamageOperation.AttackOrigin = .ability,
        context: inout BattleState,
    ) -> [ActionEvent] {
        resolveAction(ability: ability, actor: actor, abilityTarget: abilityTarget, origin: origin, entry: .ordinary, context: &context)
            .events
    }

    static func performEnemyAction(
        ability: Ability, abilityTarget: Combatant, context: inout BattleState,
    ) -> (events: [ActionEvent], performed: Bool) {
        resolveAction(
            ability: ability,
            actor: context.enemy,
            abilityTarget: abilityTarget,
            origin: .ability,
            entry: .enemyTurn,
            context: &context,
        )
    }

    private enum ActionEntry {
        case ordinary, enemyTurn
    }

    private static func resolveAction(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        origin: DamageOperation.AttackOrigin,
        entry: ActionEntry,
        context: inout BattleState,
    ) -> (events: [ActionEvent], performed: Bool) {
        let action = BattleActionContext(actor: actor, selectedTarget: abilityTarget)
        guard !context.isBattleOver, action.canContinue(in: context) else { return ([], false) }
        let previousFeedbackGroup = context.resolution.beginFeedbackGroup(eventID: context.nextEventID + 1)
        defer { context.resolution.feedbackGroupID = previousFeedbackGroup }
        let actionID = context.resolution.beginAction(action, origin: origin)
        defer { context.resolution.endAction() }
        var events: [ActionEvent] = []
        context.roster.mutateRuntime(for: actor) { $0.talents.beginAction() }
        guard BattleAbilityRules.canPayHealthCost(ability, actor: actor, in: context) else {
            if actor.role == .enemy {
                recordAction(for: actor, context: &context)
            }
            return ([], actor.role == .enemy)
        }
        let resolvedAbility = BattleAbilityRules.resolveOutcome(ability, actor: actor, in: &context)
        let facts = ResolvedActionFacts(original: ability, resolved: resolvedAbility, action: action, origin: origin, in: context)
        let blockCost = resolvedAbility.blockCost
        if blockCost > 0 {
            let balance = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: actor))
            DefensePoolEngine.set(balance - blockCost, on: actor, in: &context)
        }
        var committed = false
        defer {
            if !committed, blockCost > 0 {
                let remaining = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: actor))
                DefensePoolEngine.set(remaining + blockCost, on: actor, in: &context)
            }
        }
        if entry == .enemyTurn {
            let interception = CombatTriggerEngine.beforeEnemyAttack(facts, in: &context)
            events.append(contentsOf: interception.events)
            guard !interception.cancelled else { return (events, false) }
        }
        committed = true
        context.cardPlayRecording?.beginAction(
            id: actionID, actorID: actor.id,
            abilityID: resolvedAbility.id, isAttack: resolvedAbility.dealsCombatDamage, afterEventID: context.nextEventID,
        )
        defer { context.cardPlayRecording?.endAction(state: context) }
        if blockCost > 0 {
            events.append(context.nextEvent(
                kind: .effect, effectKind: .blockSpent, actorName: actor.name,
                abilityName: ability.name, target: actor, amount: blockCost, keyword: .block, origin: .direct,
            ))
        }
        let capturedCard = context.resolution.prepareAction(facts)
        let checkpoint = CombatCheckpoint.preparedAction(actor.id)
        checkpoint.perform(in: &context) { UniqueCombatEngine.prepareResolvedAttack(facts, in: &$0) }
        if capturedCard {
            checkpoint.perform(in: &context) { CombatTriggerEngine.captureHeroOutcome(facts, in: &$0) }
        }
        events.append(contentsOf: executePreparedAction(facts, context: &context))
        return (events, true)
    }

    private static func executePreparedAction(_ facts: ResolvedActionFacts, context: inout BattleState) -> [ActionEvent] {
        let actor = facts.action.actor
        let abilityTarget = facts.action.selectedTarget
        var resolvedAbility = prepareTalentAction(ability: facts.ability, actor: actor, in: &context)
        var events: [ActionEvent] = []
        events.append(contentsOf: spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &resolvedAbility,
            actor: actor,
            context: &context,
        ))
        CombatCheckpoint.preparedAction(actor.id).perform(in: &context) { context in
            if resolvedAbility.dealsCombatDamage {
                events.append(contentsOf: consumeHemorrhageIfActive(for: actor, in: &context))
            }
        }

        var totalDealt = 0
        var logKeyword = resolvedAbility.logDamageKeyword
        var appliedEffectLogs: [String] = []
        for operation in resolvedAbility.operations {
            switch operation {
            case let .damage(component):
                let outcome = applyDamageComponents(
                    [component], ability: resolvedAbility, actor: actor, abilityTarget: abilityTarget,
                    guaranteedCritical: facts.guaranteedCritical, context: &context,
                )
                events.append(contentsOf: outcome.events)
                totalDealt += outcome.totalDealt
                logKeyword = outcome.logDamageKeyword ?? logKeyword
            case let .effect(targeted):
                appliedEffectLogs.append(contentsOf: applyTargetedEffects(
                    [targeted], ability: resolvedAbility, actor: actor, abilityTarget: abilityTarget,
                    context: &context, events: &events,
                ))
            }
        }

        events.append(
            context.nextEvent(
                kind: .ability,
                effectKind: nil,
                actorID: actor.id,
                actorName: actor.name,
                abilityID: resolvedAbility.id,
                abilityName: resolvedAbility.name,
                abilityTier: resolvedAbility.tier,
                target: abilityTarget,
                amount: totalDealt,
                keyword: logKeyword,
                appliedEffectSummaries: appliedEffectLogs,
            ),
        )

        events.append(contentsOf: UniqueCombatEngine.repeatCardDamage(actor: actor, in: &context))
        recordAction(for: actor, context: &context)
        return events
    }

    package static func selectedEnemyAbility(for actor: Combatant, turnNumber: Int) -> Ability? {
        let tier = preferredTier(for: turnNumber)
        return actor.abilityLoadout.ability(for: tier)
            ?? actor.abilityLoadout.basic
            ?? actor.abilities.first
    }

    package static func preferredTier(for turnNumber: Int) -> AbilityTier {
        if turnNumber.isMultiple(of: AbilityTier.ultimate.cadenceTurns) {
            return .ultimate
        }
        if turnNumber.isMultiple(of: AbilityTier.skill.cadenceTurns) {
            return .skill
        }
        return .basic
    }
}

extension BattleTurnEngine {
    private struct ResolvedDamageComponent {
        let sourceEventID: Int
        let targetID: String
        let healthLost: Int
        let keyword: Keyword
        let isCritical: Bool
    }

    private struct DamageComponentOutcome {
        let events: [ActionEvent]
        let resolvedComponents: [ResolvedDamageComponent]
        let logDamageKeyword: Keyword?

        var totalDealt: Int {
            resolvedComponents.reduce(0) { $0 + $1.healthLost }
        }
    }

    // swiftlint:disable:next function_body_length - attack components resolve in deterministic order
    private static func applyDamageComponents(
        _ components: [DamageComponent],
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        guaranteedCritical: Bool,
        context: inout BattleState,
    ) -> DamageComponentOutcome {
        var events: [ActionEvent] = []
        var resolvedComponents: [ResolvedDamageComponent] = []
        var logDamageKeyword: Keyword?
        let keywordOverride = activeDamageKeywordOverride(for: actor, in: context)

        let action = BattleActionContext(actor: actor, selectedTarget: abilityTarget)
        for component in components {
            guard action.canContinue(in: context) else { break }
            let damageTarget = BattleTargetResolver.effectTarget(
                component.target,
                actor: actor,
                abilityTarget: abilityTarget,
                in: context,
            )

            var amount = component.amount
            if let condition = component.condition {
                if BattleConditionEvaluator.isMet(
                    condition,
                    actor: actor,
                    abilityTarget: abilityTarget,
                    in: context,
                ) {
                    amount += component.bonusAmount
                } else if component.bonusAmount == 0 {
                    continue
                }
            }

            let isSelfHealthCost = damageTarget.id == actor.id
            var damageKeyword = component.keyword
            if amount > 0, !isSelfHealthCost, let override = keywordOverride {
                damageKeyword = override.keyword
                amount += override.bonus
                if component.target == .abilityTarget {
                    logDamageKeyword = override.keyword
                }
            }

            let nextBurnBonus = amount > 0 && !isSelfHealthCost && damageKeyword == .burn
                ? activeNextBurnBonus(for: actor, in: context)
                : 0
            let nextStrike = nextStrikeConsumption(
                amount: amount,
                damageKeyword: damageKeyword,
                isSelfHealthCost: isSelfHealthCost,
                actor: actor,
                nextBurnBonus: nextBurnBonus,
                in: context,
            )
            if nextBurnBonus > 0 {
                amount += nextBurnBonus
            }
            let holyStrikeBurnPotency = amount
            if nextStrike.contains(.holyStrike) || nextStrike.contains(.double) {
                amount *= 2
            }

            ActiveEffectMutation.removeMatching(from: actor, in: &context) { nextStrike.consumedKinds.contains($0.kind) }
            let options: DamageOperation = isSelfHealthCost
                ? .healthCost
                : .attack(
                    tier: ability.tier,
                    origin: context.resolution.attackOrigin,
                    abilityCriticalChanceBonus: ability.criticalChanceBonus,
                    guaranteedCriticalIfEnemyBuffed: ability.guaranteedCriticalIfEnemyBuffed,
                    guaranteedCritical: guaranteedCritical || nextStrike.contains(.critical),
                    abilityHasLeech: ability.hasLeech || nextStrike.contains(.leech),
                )
            var request = DamageRequest(
                amount: amount,
                target: damageTarget,
                keyword: damageKeyword,
                sourceActorID: actor.id,
                options: options,
            )
            if !isSelfHealthCost {
                request.provenance = context.resolution.damageProvenance(for: actor.id)
            }
            request = UniqueCombatEngine.prepareDamage(request, in: &context)
            let damageOutcome = context.resolveDamage(request)
            let dealt = damageOutcome.healthLost
            let damageEvents = damageOutcome.events
            events.append(contentsOf: damageEvents)
            let componentEvent = context.nextEvent(
                kind: .abilityDamage,
                actorID: actor.id,
                actorName: actor.name,
                abilityID: ability.id,
                abilityName: ability.name,
                abilityTier: ability.tier,
                target: damageTarget,
                amount: dealt,
                keyword: damageKeyword,
                isCritical: damageOutcome.flags.contains(.critical),
                origin: .direct,
            )
            events.append(componentEvent)
            resolvedComponents.append(ResolvedDamageComponent(
                sourceEventID: componentEvent.id,
                targetID: damageTarget.id,
                healthLost: dealt,
                keyword: damageKeyword,
                isCritical: componentEvent.isCritical,
            ))

            if case .landed = damageOutcome.damageImpact {
                if nextStrike.contains(.holyStrike) {
                    events.append(contentsOf: context.applyDecayingDoT(
                        keyword: .burn, potency: holyStrikeBurnPotency, to: damageTarget,
                        sourceActorID: actor.id, application: .ability,
                    ))
                }
                events.append(contentsOf: applyDoTStackFromDamage(
                    keyword: damageKeyword,
                    potency: damageKeyword == .burn || damageKeyword == .poison ? dealt : amount,
                    to: damageTarget,
                    sourceActorID: actor.id, context: &context,
                ))
            }
        }

        return DamageComponentOutcome(
            events: events,
            resolvedComponents: resolvedComponents,
            logDamageKeyword: logDamageKeyword,
        )
    }

    static func applyDoTStackFromDamage(
        keyword: Keyword,
        potency: Int,
        to target: Combatant,
        sourceActorID: String,
        context: inout BattleState,
    ) -> [ActionEvent] {
        DoTApplicator.applyDoT(
            keyword: keyword,
            potency: potency,
            to: target,
            sourceActorID: sourceActorID,
            application: .afterHit,
            in: &context,
        ) ?? []
    }

    static func activeDamageKeywordOverride(
        for actor: Combatant,
        in context: BattleState,
    ) -> (keyword: Keyword, bonus: Int)? {
        for active in context.roster.activeEffects(for: actor) where active.remainingTurns > 0 {
            if case let .damageKeywordOverride(keyword, bonus, _) = active.effect {
                return (keyword, bonus)
            }
        }
        return nil
    }

    private static func hasActiveEffect(
        for actor: Combatant,
        in context: BattleState,
        where matches: (Effect) -> Bool,
    ) -> Bool {
        context.roster.activeEffects(for: actor).contains { matches($0.effect) }
    }

    private static func nextStrikeConsumption(
        amount: Int,
        damageKeyword: Keyword?,
        isSelfHealthCost: Bool,
        actor: Combatant,
        nextBurnBonus: Int,
        in context: BattleState,
    ) -> NextStrikeConsumption {
        guard amount > 0, !isSelfHealthCost else { return [] }
        var consumption: NextStrikeConsumption = []
        let holyStrike = damageKeyword == .holy
            && hasActiveEffect(for: actor, in: context) { $0 == .nextHolyStrike }
        if holyStrike {
            consumption.insert(.holyStrike)
        }
        if hasActiveEffect(for: actor, in: context, where: { $0 == .nextStrikeDouble }), !holyStrike {
            consumption.insert(.double)
        }
        if hasActiveEffect(for: actor, in: context, where: { $0 == .nextStrikeCritical }) {
            consumption.insert(.critical)
        }
        if hasActiveEffect(for: actor, in: context, where: { $0 == .nextStrikeLeech }) {
            consumption.insert(.leech)
        }
        if nextBurnBonus > 0 {
            consumption.insert(.burnBonus)
        }
        return consumption
    }

    private static func activeNextBurnBonus(
        for actor: Combatant,
        in context: BattleState,
    ) -> Int {
        context.roster.activeEffects(for: actor).reduce(0) { sum, active in
            if case let .nextBurnBonus(amount) = active.effect {
                return sum + amount
            }
            return sum
        }
    }

    private static func removeActiveEffect(
        for actor: Combatant,
        in context: inout BattleState,
        where matches: (Effect) -> Bool,
    ) {
        ActiveEffectMutation.removeMatching(from: actor, in: &context, where: matches)
    }

    private static func consumeHemorrhageIfActive(
        for actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var hemorrhageDamage: Int?
        var sourceActorID: String?
        for active in context.roster.activeEffects(for: actor) {
            if case let .hemorrhage(damage) = active.effect {
                hemorrhageDamage = damage
                sourceActorID = active.sourceActorID
                break
            }
        }
        guard let hemorrhageDamage else { return [] }
        removeActiveEffect(for: actor, in: &context) {
            if case .hemorrhage = $0 {
                return true
            }
            return false
        }
        let casterID = sourceActorID ?? actor.id
        let hemorrhageOutcome = context.resolveDamage(
            DamageRequest(
                amount: hemorrhageDamage,
                target: actor,
                keyword: .bleed,
                sourceActorID: casterID,
                options: .reaction(),
            ),
        )
        var hemorrhageEvents = hemorrhageOutcome.events
        if let lastIndex = hemorrhageEvents.indices.last {
            let event = hemorrhageEvents[lastIndex]
            hemorrhageEvents[lastIndex] = event.with(
                effectKind: .hemorrhageTriggered,
                actorID: actor.id,
                actorName: actor.name,
                abilityName: "Hemorrhage",
            )
        } else if hemorrhageOutcome.healthLost > 0 {
            hemorrhageEvents.append(context.nextEvent(
                kind: .effect,
                effectKind: .hemorrhageTriggered,
                actorID: actor.id,
                actorName: actor.name,
                abilityName: "Hemorrhage",
                target: actor,
                amount: hemorrhageOutcome.healthLost,
                keyword: .bleed,
            ))
        }
        hemorrhageEvents.append(contentsOf: DoTApplicator.applyBleed(
            potency: hemorrhageDamage,
            to: actor,
            sourceActorID: casterID,
            application: .afterHit,
            in: &context,
        ))
        return hemorrhageEvents
    }

    private static func applyTargetedEffects(
        _ effects: [TargetedEffect],
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        context: inout BattleState,
        events: inout [ActionEvent],
    ) -> [String] {
        var appliedEffectLogs: [String] = []
        let action = BattleActionContext(actor: actor, selectedTarget: abilityTarget)
        for targetedEffect in effects {
            guard action.canContinue(in: context) else { break }
            if let condition = targetedEffect.condition,
               !BattleConditionEvaluator.isMet(
                   condition,
                   actor: actor,
                   abilityTarget: abilityTarget,
                   in: context,
               ) {
                continue
            }

            let effect = targetedEffect.effect
            let effectTargets = BattleTargetResolver.effectTargets(
                targetedEffect.target,
                actor: actor,
                abilityTarget: abilityTarget,
                in: context,
            )

            guard let handler = EffectHandlers.handler(for: effect.kind) else {
                logger.error("Missing effect handler for \(String(describing: effect.kind), privacy: .public)")
                continue
            }
            var didApply = false
            for effectTarget in effectTargets {
                guard action.canContinue(in: context) else { break }
                if shouldSkipEffectOnDefeatedTarget(effect, target: effectTarget, actor: actor, context: context)
                    || CombatTriggerEngine.preventsPurgedEffect(effect, on: effectTarget, in: context) {
                    continue
                }
                let outcome = handler.apply(
                    effect,
                    ability: ability,
                    source: actor,
                    target: effectTarget,
                    in: &context,
                )
                events.append(contentsOf: outcome.events)
                didApply = didApply || outcome.didApply
            }
            if didApply {
                appliedEffectLogs.append(effect.summary)
            }
        }
        return appliedEffectLogs
    }

    private static func shouldSkipEffectOnDefeatedTarget(
        _ effect: Effect,
        target: Combatant,
        actor _: Combatant,
        context: BattleState,
    ) -> Bool {
        guard context.roster.health(for: target) <= 0 else { return false }
        return !effect.canApplyToDefeatedTarget
    }

    private static func recordAction(
        for actor: Combatant,
        context: inout BattleState,
    ) {
        context.actionCount += 1
        context.roster.mutateRuntime(for: actor) { runtime in
            runtime.markActed()
        }
    }
}
