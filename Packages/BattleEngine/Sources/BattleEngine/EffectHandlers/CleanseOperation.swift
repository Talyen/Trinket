import TrinketContent
import TrinketCore

enum CleanseOperation {
    enum Selection {
        case all(Keyword?)
        case random
    }

    enum Propagation {
        case primary, secondary
    }

    struct Outcome {
        let removed: [ActiveEffect]
        let application: EffectApplyOutcome
        var events: [ActionEvent] {
            application.events
        }
    }

    static func resolve(
        _ selection: Selection,
        source: Combatant,
        target: Combatant,
        abilityName: String,
        baseHeal: Int = 0,
        healPerDebuff: Int = 0,
        healTarget: Combatant? = nil,
        propagation: Propagation = .primary,
        origin: ActionEvent.Origin = .automatic,
        in context: inout BattleState,
    ) -> Outcome {
        var effects = context.roster.activeEffects(for: target)
        let removed: [ActiveEffect] = switch selection {
        case let .all(keyword): EffectRemoval.removeDebuffs(from: &effects, keyword: keyword)
        case .random: EffectRemoval.removeRandomDebuff(from: &effects, using: &context.rng).map { [$0] } ?? []
        }
        context.roster.setActiveEffects(effects, for: target)
        if let owner = context.roster.participant(for: target), owner.isPartyMember,
           !context.roster.hasPendingActionSkip(for: target) {
            context.ownersSkippingThisPlayerTurn.remove(owner)
        }
        let healAmount = baseHeal + healPerDebuff * removed.count
        guard !removed.isEmpty else {
            var events = CombatTriggerEngine.afterHeroCleanse(source: source, target: target, removed: [], in: &context)
            if healAmount > 0 {
                events.append(contentsOf: context.healEmitting(
                    amount: healAmount, target: healTarget ?? target, source: source, abilityName: abilityName,
                    isDirectCardHeal: context.hasHeroCard(for: source.id),
                ))
            }
            if propagation == .primary {
                events.append(contentsOf: CombatTriggerEngine.cleanseOtherPartyMember(source: source, target: target, in: &context))
            }
            return Outcome(removed: [], application: EffectApplyOutcome(events: events, didApply: !events.isEmpty))
        }
        if propagation == .secondary {
            let triggers = context.modifiers(for: source.id).triggers
            if triggers.cleanseDodgeChanceBonus > 0 {
                let duration = max(1, triggers.cleanseDodgeChanceBonusTurns)
                context.roster.mutateRuntime(for: target) {
                    $0.talents.timed.dodge.amount += triggers.cleanseDodgeChanceBonus
                    $0.talents.timed.dodge.expiresAtTurn = max($0.talents.timed.dodge.expiresAtTurn, context.turnCount + duration)
                }
            }
        }
        let events = reactions(
            removed: removed, abilityName: abilityName, source: source, target: target,
            healAmount: healAmount, healTarget: healTarget ?? target,
            allowMassCleanse: propagation == .primary, origin: origin, in: &context,
        )
        return Outcome(removed: removed, application: EffectApplyOutcome(events: events, didApply: true))
    }

    private static func reactions(
        removed: [ActiveEffect],
        abilityName: String,
        source: Combatant,
        target: Combatant,
        healAmount: Int? = nil,
        healTarget: Combatant? = nil,
        allowMassCleanse: Bool = true,
        origin: ActionEvent.Origin = .automatic,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var countsByKeyword: [Keyword: Int] = [:]
        for item in removed {
            countsByKeyword[item.keyword, default: 0] += 1
        }
        var events = CombatTriggerEngine.afterHeroCleanse(
            source: source, target: target, removed: removed.map(\.keyword), in: &context,
        )
        for (keyword, _) in countsByKeyword.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .cleanseApplied,
                actorName: source.name,
                abilityName: abilityName,
                target: target,
                amount: 0,
                keyword: keyword,
                origin: origin,
            ))
        }
        if let healAmount, let healTarget, healAmount > 0 {
            events.append(contentsOf: context.healEmitting(
                amount: healAmount,
                target: healTarget,
                source: source,
                abilityName: abilityName,
                isDirectCardHeal: context.hasHeroCard(for: source.id),
            ))
        }
        events.append(contentsOf: CombatTriggerEngine.healAfterCleanse(source: source, target: target, in: &context).events)
        events.append(contentsOf: CombatTriggerEngine.healWearerAfterCleanse(source: source, in: &context).events)
        events.append(contentsOf: CombatTriggerEngine.drawAfterCleanse(source: source, in: &context))
        events.append(contentsOf: CombatTriggerEngine.afterCleanseAction(
            source: source,
            target: target,
            removedCount: removed.count,
            allowMassCleanse: allowMassCleanse,
            in: &context,
        ))
        for (keyword, count) in countsByKeyword.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            events.append(contentsOf: CombatTriggerEngine.afterCleanseKeywordReaction(
                source: source,
                removedKeyword: keyword,
                removedCount: count,
                in: &context,
            ))
        }
        events.append(contentsOf: CombatTriggerEngine.reflectCleansedEffects(removed, source: source, in: &context))
        return events
    }
}
