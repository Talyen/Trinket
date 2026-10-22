import Foundation
import TrinketCore

public extension Ability {
    /// Presentation resolves from rule data, never from the cached English description.
    func localizedSummary(locale: Locale = .current) -> LocalizedGameText {
        if let descriptionOverride {
            return ContentCopy.description(descriptionOverride, locale: locale)
        }
        return localizedGeneratedSummary(locale: locale)
    }

    internal func localizedGeneratedSummary(locale: Locale) -> LocalizedGameText {
        let operations: [LocalizedGameText]
        if let outcomeBranches, !outcomeBranches.isEmpty {
            let alternatives = outcomeBranches.map { branch in
                if branch.randomizeDamageKeywords {
                    let amount = branch.damageComponents.first?.amount ?? 0
                    return LocalizedGameText(L10n.rule_ability_random_damage(amount), locale: locale, values: ["damage": amount])
                }
                return LocalizedGameText.joining(branch.operations.flatMap { localizedOperation($0, locale: locale) })
            }
            operations = alternatives.dropFirst().reduce(into: Array(alternatives.prefix(1))) { result, next in
                guard let first = result.first else { result = [next]; return }
                let previous = first.scoped(to: "first")
                let next = next.scoped(to: "second")
                let text = LocalizedGameText(
                    L10n.rule_ability_alternative(previous.markedText, next.markedText),
                    locale: locale,
                    values: previous.values.merging(next.values) { first, _ in first },
                )
                result = [text]
            }
        } else {
            operations = self.operations.flatMap { localizedOperation($0, locale: locale) }
        }
        var lines = operations
        if guaranteedCriticalIfEnemyBuffed {
            lines.append(LocalizedGameText(L10n.rule_ability_critical_buff, locale: locale))
        } else if criticalChanceBonus > 0 {
            let chance = CombatRounding.rounded((criticalChanceBonus * 100).rounded(.towardZero))
            lines.append(LocalizedGameText(L10n.rule_ability_critical_bonus(chance), locale: locale, values: ["chance": chance]))
        }
        if repeatsManaEmpowerment {
            lines.append(LocalizedGameText(L10n.rule_ability_mana_rider, locale: locale))
        }
        if hasLeech {
            lines.append(LocalizedGameText(L10n.rule_ability_leech, locale: locale))
        }
        return LocalizedGameText.joining(lines)
    }

    private func localizedOperation(_ operation: AbilityOperation, locale: Locale) -> [LocalizedGameText] {
        switch operation {
        case let .effect(targeted):
            var text = EffectPresentation.localizedDescription(for: targeted.effect, locale: locale)
            if targeted.chance < 1 {
                let chance = CombatRounding.wholePercent(targeted.chance)
                let resource: LocalizedStringResource = if case let .resourceGain(.gold, amount) = targeted.effect, stealsGold {
                    L10n.rule_ability_chance_steal_gold(chance, amount)
                } else {
                    L10n.rule_ability_chance(chance, text.markedText)
                }
                text = LocalizedGameText(
                    resource, locale: locale,
                    values: text.values.merging(["chance": chance]) { _, chance in chance },
                )
            }
            return [conditioned(text, on: targeted.condition, locale: locale)]
        case let .damage(component):
            if component.target == .actor {
                return [LocalizedGameText(
                    L10n.rule_ability_lose_health(component.amount),
                    locale: locale,
                    values: ["health": component.amount],
                )]
            }
            var text: LocalizedGameText
            let keyword = component.keyword.markedName(locale: locale)
            if let scaling = component.scaling {
                switch scaling {
                case let .actorBlockFraction(divisor, _):
                    let resource = divisor == 2 ? L10n.rule_ability_half_block_damage(keyword) : L10n.rule_ability_fraction_block_damage(
                        keyword,
                        divisor,
                    )
                    text = LocalizedGameText(resource, locale: locale, values: ["divisor": divisor])
                }
            } else {
                text = LocalizedGameText(
                    L10n.rule_ability_damage(component.amount, keyword),
                    locale: locale,
                    values: ["damage": component.amount],
                )
            }
            if component.hasLeech {
                text = LocalizedGameText(L10n.rule_ability_with_leech(text.markedText), locale: locale, values: text.values)
            }
            guard let condition = component.condition else { return [text] }
            if component.bonusAmount > 0 {
                let bonus = LocalizedGameText(
                    L10n.rule_ability_conditional_bonus(
                        component.bonusAmount,
                        keyword,
                        condition.localizedClause(locale: locale).markedText,
                    ),
                    locale: locale, values: ["bonus": component.bonusAmount],
                )
                return [text, bonus]
            }
            return [conditioned(text, on: condition, locale: locale)]
        }
    }

    private func conditioned(_ text: LocalizedGameText, on condition: DamageCondition?, locale: Locale) -> LocalizedGameText {
        guard let condition else { return text }
        return LocalizedGameText(
            L10n.rule_ability_conditional(text.markedText, condition.localizedClause(locale: locale).markedText),
            locale: locale, values: text.values,
        )
    }
}
