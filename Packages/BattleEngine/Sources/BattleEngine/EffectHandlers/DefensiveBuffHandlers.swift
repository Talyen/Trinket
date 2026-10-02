import Foundation
import TrinketContent
import TrinketCore

struct BlockBuffHandler: BattleEffectHandler {
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = DefensePoolEngine.blockPoints(in: stacks)
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): Absorbs up to \(total) incoming damage.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .shield(_, amount) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let gain = context.applyBlockGain(
            amount,
            to: target,
            source: source,
            abilityName: ability.name,
            origin: .direct,
        )
        return EffectApplyOutcome(events: gain.applied > 0 ? gain.events : [], didApply: gain.applied > 0)
    }
}

struct FlagEffectHandler: BattleEffectHandler {
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let effect = stacks.first?.effect,
              let text = EffectPresentation.battleSummaryPhrase(for: effect) else { return nil }
        return EffectSummary(keyword: keyword, text: text)
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        let event: (kind: ActionEvent.EffectOutcome, amount: Int)
        switch effect {
        case .nextHolyStrike: event = (.nextHolyStrikeApplied, 0)
        case .nextStrikeDouble: event = (.nextStrikeDoubleApplied, 0)
        case .evadeNextHit: event = (.evadeNextHitApplied, 0)
        case .nextStrikeCritical: event = (.criticalChanceApplied, 100)
        case .nextStrikeLeech: event = (.leechApplied, 0)
        case .nextStrikeDamageKeywordOverride: event = (.damageKeywordOverrideApplied, 0)
        case .freezeNextAttacker: event = (.controlApplied, 0)
        default: return EffectApplyOutcome(events: [], didApply: false)
        }
        return ActiveEffectMutation.replaceAndEmit(
            effect,
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0 == effect },
            event: (event.kind, event.amount, effect.keyword),
        )
    }
}

struct ShieldFromResourceHandler: BattleEffectHandler {
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        let block: Int
        var payment: ManaPayment?
        switch effect {
        case .convertManaToBlock:
            let mana = context.mana(of: target)
            guard mana > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            payment = context.payMana(mana, for: target)
            block = mana
        case .shieldFromMana:
            let mana = context.mana(of: target)
            guard mana > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            block = mana
        case .shieldFromHalfMana:
            let half = context.mana(of: target) / 2
            guard half > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            block = half
        case let .shieldFromGold(goldPerBlock):
            guard goldPerBlock > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            let fromGold = context.gold / goldPerBlock
            guard fromGold > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            block = fromGold
        default:
            return EffectApplyOutcome(events: [], didApply: false)
        }

        let applied = context.applyBlockGain(
            block,
            to: target,
            source: source,
            abilityName: ability.name,
            origin: .direct,
        )
        var events: [ActionEvent] = []
        if let payment {
            events = CombatTriggerEngine.afterSpendMana(payment, in: &context)
        }
        events.append(contentsOf: applied.events)
        return EffectApplyOutcome(events: events, didApply: applied.applied > 0)
    }
}
