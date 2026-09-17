import Foundation
import TrinketContent
import TrinketCore

struct BlockBuffHandler: BattleEffectHandler {
    let kind: EffectKind = .shield

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
    let flag: Effect
    let appliedEffectKind: ActionEvent.EffectOutcome
    let amount: Int
    let keyword: Keyword
    let summaryText: String

    var kind: EffectKind {
        flag.kind
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard !stacks.isEmpty else { return nil }
        return EffectSummary(keyword: keyword, text: summaryText)
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard effect == flag else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        return ActiveEffectMutation.replaceAndEmit(
            flag,
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0 == flag },
            event: (appliedEffectKind, amount, keyword),
        )
    }
}

struct ShieldFromResourceHandler: BattleEffectHandler {
    enum Mode {
        case convertManaToBlock
        case shieldFromMana
        case shieldFromHalfMana
        case shieldFromGold
    }

    let mode: Mode
    let kind: EffectKind

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard effect.kind == kind else {
            return EffectApplyOutcome(events: [], didApply: false)
        }

        let block: Int
        var payment: ManaPayment?
        switch mode {
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
        case .shieldFromGold:
            guard case let .shieldFromGold(goldPerBlock) = effect, goldPerBlock > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            let fromGold = context.gold / goldPerBlock
            guard fromGold > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            block = fromGold
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
