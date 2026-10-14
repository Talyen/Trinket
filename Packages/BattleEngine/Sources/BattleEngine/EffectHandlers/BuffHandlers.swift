import TrinketContent
import TrinketCore

struct StackingAmountBuffHandler: BattleEffectHandler {
    private static func amount(_ effect: Effect) -> Int? {
        switch effect {
        case let .thorns(amount), let .nextBurnBonus(amount): amount
        default: nil
        }
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let kind = stacks.first?.effect.kind else { return nil }
        let total = TimedBuffSummary.summedAmount(in: stacks) { $0.kind == kind ? Self.amount($0) : nil }
        guard total > 0 else { return nil }
        let text: String
        switch kind {
        case .thorns: text = "Thorns: Deals \(total) Thorns damage to the next attacker"
        case .nextBurnBonus: text = "Kindled: Next Burn attack deals +\(total) damage"
        default: return nil
        }
        return EffectSummary(keyword: keyword, text: text)
    }

    func apply(
        _ effect: Effect, ability: Ability, source: Combatant, target: Combatant, in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard let amount = Self.amount(effect), amount > 0 else { return EffectApplyOutcome(events: [], didApply: false) }
        let existing = TimedBuffSummary.summedAmount(in: context.roster.activeEffects(for: target)) {
            $0.kind == effect.kind ? Self.amount($0) : nil
        }
        let total = SaturatedArithmetic.saturatingAdd(existing, amount)
        let stacked: Effect
        let event: ActionEvent.EffectOutcome
        switch effect {
        case .thorns: stacked = .thorns(total); event = .thornsApplied
        case .nextBurnBonus: stacked = .nextBurnBonus(total); event = .nextBurnBonusApplied
        default: return EffectApplyOutcome(events: [], didApply: false)
        }
        return ActiveEffectMutation.replaceAndEmit(
            stacked, to: target, source: source, ability: ability, in: &context,
            replacing: { $0.kind == effect.kind }, event: (event, total, effect.keyword),
        )
    }
}

struct ThornsFromBlockFractionHandler: BattleEffectHandler {
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .thornsFromBlockFraction(divisor, minimum) = effect,
              divisor > 0
        else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: target))
        let amount = max(minimum, block / divisor)
        guard amount > 0 else { return EffectApplyOutcome(events: [], didApply: false) }
        return StackingAmountBuffHandler().apply(
            .thorns(amount), ability: ability, source: source, target: target, in: &context,
        )
    }
}

struct StoredEffectHandler: BattleEffectHandler {
    func apply(
        _ effect: Effect, ability: Ability, source: Combatant, target: Combatant, in context: inout BattleState,
    ) -> EffectApplyOutcome {
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
        case let .restoreManaOnHit(amount, turns):
            context.appendEffect(effect, to: target, sourceID: source.id, remainingTurns: turns)
            return EffectApplyOutcome(events: [context.nextEvent(
                kind: .effect(.manaShieldApplied), source: .init(source),
                abilityID: ability.id, abilityName: ability.name, target: target,
                amount: amount, keyword: .mana, origin: .direct,
            )], didApply: true)
        default:
            return EffectApplyOutcome(events: [], didApply: false)
        }
        return ActiveEffectMutation.replaceAndEmit(
            effect, to: target, source: source, ability: ability, in: &context,
            replacing: {
                switch effect {
                case .onHitDamage: $0.kind == effect.kind && $0.keyword == effect.keyword
                case .marked, .criticalChanceBonus, .damageKeywordOverride, .hemorrhage: $0.kind == effect.kind
                default: $0 == effect
                }
            },
            event: event,
        )
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let first = stacks.first?.effect else { return nil }
        switch first {
        case .onHitDamage:
            let amount = TimedBuffSummary.maxAmount(in: stacks) { effect in
                guard case let .onHitDamage(_, value) = effect else { return nil }
                return value
            }
            guard amount > 0 else { return nil }
            let label = keyword == .freeze ? "Glacial Ward" : "\(keyword.rawValue) Ward"
            return EffectSummary(keyword: keyword, text: "\(label): Deals \(amount) \(keyword.rawValue) damage to the next attacker")

        case .marked:
            let bonus = TimedBuffSummary.maxAmount(in: stacks) { effect in
                guard case let .marked(value, _) = effect else { return nil }
                return value
            }
            guard bonus > 0 else {
                return EffectSummary(keyword: keyword, text: "Marked: The next attack deals extra damage and removes Marked")
            }
            let suffix = TimedBuffSummary.durationSuffix(in: stacks, separator: "\n")
            return EffectSummary(
                keyword: keyword,
                text: "Marked: The next attack deals +\(bonus) damage and removes Marked\(suffix)",
            )

        case .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride:
            return timedSummary(for: stacks, keyword: keyword)

        case .hemorrhage:
            let amount = TimedBuffSummary.maxAmount(in: stacks) { effect in
                guard case let .hemorrhage(value) = effect else { return nil }
                return value
            }
            guard amount > 0 else { return nil }
            return EffectSummary(keyword: keyword, text: "Hemorrhage: Takes \(amount) Bleed damage on next attack")

        case .nextHolyStrike, .nextStrikeDouble, .playNextCardTwice, .evadeNextHit, .nextStrikeCritical,
             .nextStrikeLeech, .nextStrikeDamageKeywordOverride, .freezeNextAttacker:
            guard let text = EffectPresentation.battleSummaryPhrase(for: first) else { return nil }
            return EffectSummary(keyword: keyword, text: text)

        default: return nil
        }
    }

    private func timedSummary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let first = stacks.first?.effect else { return nil }
        let suffix = TimedBuffSummary.durationSuffix(in: stacks)
        let text: String
        switch first {
        case .criticalChanceBonus:
            let percent = TimedBuffSummary.maxPercent(in: stacks) { effect in
                guard case let .criticalChanceBonus(value, _) = effect else { return nil }
                return value
            }
            guard percent > 0 else { return nil }
            text = "Focused: Increases Critical chance by +\(CombatRounding.rounded((percent * 100).rounded(.towardZero)))%\(suffix)"

        case .restoreManaOnHit:
            let amount = TimedBuffSummary.summedAmount(in: stacks) { effect in
                guard case let .restoreManaOnHit(value, _) = effect else { return nil }
                return value
            }
            guard amount > 0 else { return nil }
            text = "Mana Shield: Restores \(amount) Mana when hit\(suffix)"

        case let .damageKeywordOverride(overrideKeyword, bonus, _):
            text = "Consecrated: Attacks deal \(overrideKeyword.rawValue) damage (+\(bonus))\(suffix)"

        default: return nil
        }
        return EffectSummary(keyword: keyword, text: text)
    }
}

struct PartyDamageBonusHandler: BattleEffectHandler {
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target _: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .partyDamageBonus(amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let recipient = BattleAbilityRules.preparationRecipient(for: source, in: context)
        context.resolution.preparePartyDamage(amount, recipientID: recipient.id)
        let event = context.nextEvent(
            kind: .effect(.partyDamagePreparationApplied), source: .init(source),
            abilityID: ability.id, abilityName: ability.name, target: recipient, amount: amount, keyword: .physical, origin: .direct,
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
