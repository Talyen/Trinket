import Foundation
import TrinketContent
import TrinketCore

public extension AffixModifier {
    func apply(to profile: inout CombatModifierProfile) {
        if applyMaximumStat(to: &profile) {
            return
        }
        if applyCombatBonus(to: &profile) {
            return
        }
        applyDurationBonus(to: &profile)
    }

    private func applyMaximumStat(to profile: inout CombatModifierProfile) -> Bool {
        switch self {
        case let .maximumHealth(amount):
            profile.maximumHealthBonus += amount
        case let .maximumMana(amount):
            profile.maximumManaBonus += amount
        default:
            return false
        }
        return true
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func applyCombatBonus(to profile: inout CombatModifierProfile) -> Bool {
        switch self {
        case let .damageDealt(keyword, amount):
            profile.damageDealtBonus[keyword, default: 0] += amount
        case let .poisonDamageDealtPercent(amount):
            profile.poisonDamageDealtPercent += amount
        case let .healthRestored(amount):
            profile.healthRestoredBonus += amount
        case let .leechGainedPercent(amount):
            profile.leechGainedBonus += amount
        case let .leechHealing(amount):
            profile.leechHealingBonus += amount
        case let .goldGained(amount):
            profile.goldGainedBonus += amount
        case let .goldGainedPercent(amount):
            profile.goldGainedPercent += amount
        case let .blockGained(amount):
            profile.blockGainedBonus += amount
        case let .damageTakenPercent(keyword, amount):
            profile.damageTakenReduction[keyword, default: 0] += amount
        case let .damageTakenFlat(keyword, amount):
            profile.damageTakenFlat[keyword, default: 0] += amount
        case let .damageTakenVulnerability(keyword, amount):
            profile.damageTakenVulnerability[keyword, default: 0] += amount
        case let .companionDamageDealt(amount):
            profile.companionDamageDealtBonus += amount
        case let .companionBleedDamageDealt(amount):
            profile.companionBleedDamageDealtBonus += amount
        case let .outgoingDamagePercent(amount):
            profile.outgoingDamagePercent += amount
        case let .incomingDamageReductionPercent(amount):
            profile.incomingDamageReductionPercent += amount
        case let .dodgeChanceBonus(amount):
            profile.triggers.dodgeChanceBonus += amount
        default:
            return false
        }
        return true
    }

    private func applyDurationBonus(to profile: inout CombatModifierProfile) {
        if case let .bleedDuration(amount) = self {
            profile.bleedDurationBonus += amount
        }
    }
}
