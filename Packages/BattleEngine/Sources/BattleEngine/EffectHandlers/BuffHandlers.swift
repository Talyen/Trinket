import Foundation
import TrinketContent
import TrinketCore

extension EffectHandlers {
    static func stackingAmount(_ effect: Effect) -> Int? {
        switch effect {
        case let .thorns(amount), let .nextBurnBonus(amount): amount
        default: nil
        }
    }

    static func summarizeStackingAmountBuff(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let kind = stacks.first?.effect.kind else { return nil }
        let total = TimedBuffSummary.summedAmount(in: stacks) { $0.kind == kind ? Self.stackingAmount($0) : nil }
        guard total > 0 else { return nil }
        let text: LocalizedStringResource
        switch kind {
        case .thorns: text = L10n.summary_buffhandlers_3e68ff3d38da(total)
        case .nextBurnBonus: text = L10n.summary_buffhandlers_d0133f55b23d(total)
        default: return nil
        }
        return EffectSummary(keyword: keyword, resource: text)
    }

    static func summarizeStoredEffect(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let first = stacks.first?.effect else { return nil }
        switch first {
        case .onHitDamage:
            let amount = TimedBuffSummary.maxAmount(in: stacks) { effect in
                guard case let .onHitDamage(_, value) = effect else { return nil }
                return value
            }
            guard amount > 0 else { return nil }
            let label = keyword == .freeze ? L10n.summary_buffhandlers_92e5596a3512 : L10n
                .summary_buffhandlers_a96afd45f5af(keyword.nameResource)
            return EffectSummary(keyword: keyword, resource: L10n.summary_buffhandlers_cb1ecaff8635(label, amount, keyword.nameResource))

        case .marked:
            let bonus = TimedBuffSummary.maxAmount(in: stacks) { effect in
                guard case let .marked(value, _) = effect else { return nil }
                return value
            }
            guard bonus > 0 else {
                return EffectSummary(keyword: keyword, resource: L10n.summary_buffhandlers_f62a40fbfc30)
            }
            let suffix = TimedBuffSummary.durationResource(in: stacks, separator: "\n")
            return EffectSummary(
                keyword: keyword,
                resource: L10n.summary_buffhandlers_f62c4f1d4746(bonus, suffix),
            )

        case .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride:
            return summarizeTimedStored(for: stacks, keyword: keyword)

        case .hemorrhage:
            let amount = TimedBuffSummary.maxAmount(in: stacks) { effect in
                guard case let .hemorrhage(value) = effect else { return nil }
                return value
            }
            guard amount > 0 else { return nil }
            return EffectSummary(keyword: keyword, resource: L10n.summary_buffhandlers_3376c64cba02(amount))

        case .nextHolyStrike, .nextStrikeDouble, .playNextCardTwice, .evadeNextHit, .nextStrikeCritical,
             .nextStrikeLeech, .nextStrikeDamageKeywordOverride, .freezeNextAttacker:
            guard let text = BattleCopy.flagSummary(first) else { return nil }
            return EffectSummary(keyword: keyword, resource: text)

        default: return nil
        }
    }

    private static func summarizeTimedStored(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let first = stacks.first?.effect else { return nil }
        let suffix = TimedBuffSummary.durationResource(in: stacks)
        let text: LocalizedStringResource
        switch first {
        case .criticalChanceBonus:
            let percent = TimedBuffSummary.maxPercent(in: stacks) { effect in
                guard case let .criticalChanceBonus(value, _) = effect else { return nil }
                return value
            }
            guard percent > 0 else { return nil }
            text = L10n.summary_buffhandlers_ead74836fb5e(CombatRounding.rounded((percent * 100).rounded(.towardZero)), suffix)

        case .restoreManaOnHit:
            let amount = TimedBuffSummary.summedAmount(in: stacks) { effect in
                guard case let .restoreManaOnHit(value, _) = effect else { return nil }
                return value
            }
            guard amount > 0 else { return nil }
            text = L10n.summary_buffhandlers_b517a9d4c192(amount, suffix)

        case let .damageKeywordOverride(overrideKeyword, bonus, _):
            text = L10n.summary_buffhandlers_12d886cfa2de(overrideKeyword.nameResource, bonus, suffix)

        default: return nil
        }
        return EffectSummary(keyword: keyword, resource: text)
    }
}

extension EffectApplication {
    func applyStackingAmountBuff(in context: inout BattleState) -> EffectApplyOutcome {
        guard let amount = EffectHandlers.stackingAmount(effect), amount > 0 else { return EffectApplyOutcome(didApply: false) }
        let existing = TimedBuffSummary.summedAmount(in: context.roster.activeEffects(for: target)) {
            $0.kind == effect.kind ? EffectHandlers.stackingAmount($0) : nil
        }
        let total = SaturatedArithmetic.saturatingAdd(existing, amount)
        let stacked: Effect
        let event: ActionEvent.EffectOutcome
        switch effect {
        case .thorns: stacked = .thorns(total); event = .thornsApplied
        case .nextBurnBonus: stacked = .nextBurnBonus(total); event = .nextBurnBonusApplied
        default: return EffectApplyOutcome(didApply: false)
        }
        return replacingEffect(stacked).store(replacing: { $0.kind == effect.kind }, event: (event, total, effect.keyword), in: &context)
    }

    func applyStoredEffect(in context: inout BattleState) -> EffectApplyOutcome {
        let event: (kind: ActionEvent.EffectOutcome, amount: Int, keyword: Keyword)
        switch effect {
        case let .onHitDamage(keyword, amount) where amount > 0:
            event = (.wardApplied, amount, keyword)
        case let .marked(bonus, _):
            event = (.markedApplied, bonus, .physical)
        case let .criticalChanceBonus(percent, _):
            event = (.criticalChanceApplied, CombatRounding.rounded((percent * 100).rounded(.towardZero)), .physical)
        case let .damageKeywordOverride(keyword, bonus, _):
            event = (.damageKeywordOverrideApplied, bonus, keyword)
        case let .hemorrhage(amount) where amount > 0:
            event = (.hemorrhageApplied, amount, .bleed)
        case .nextHolyStrike: event = (.nextHolyStrikeApplied, 0, effect.keyword)
        case .nextStrikeDouble: event = (.nextStrikeDoubleApplied, 0, effect.keyword)
        case .playNextCardTwice: event = (.playNextCardTwiceApplied, 0, effect.keyword)
        case .evadeNextHit: event = (.evadeNextHitApplied, 0, effect.keyword)
        case .nextStrikeCritical: event = (.criticalChanceApplied, 100, effect.keyword)
        case .nextStrikeLeech: event = (.leechApplied, 0, effect.keyword)
        case .nextStrikeDamageKeywordOverride: event = (.damageKeywordOverrideApplied, 0, effect.keyword)
        case .freezeNextAttacker: event = (.controlApplied, 0, effect.keyword)
        case let .restoreManaOnHit(amount, _):
            return store(replacing: { _ in false }, event: (.manaShieldApplied, amount, .mana), in: &context)
        default:
            return EffectApplyOutcome(didApply: false)
        }
        return store(
            replacing: {
                switch effect {
                case .onHitDamage: $0.kind == effect.kind && $0.keyword == effect.keyword
                case .marked, .criticalChanceBonus, .damageKeywordOverride, .hemorrhage: $0.kind == effect.kind
                default: $0 == effect
                }
            },
            event: event,
            in: &context,
        )
    }
}
