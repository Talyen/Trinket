import Foundation
import TrinketCore
import TrinketContent

public extension AffixModifier {
    public func apply(to profile: inout CombatModifierProfile) {
        if applyPrimaryStat(to: &profile) { return }
        if applyMaximumStat(to: &profile) { return }
        if applyCombatBonus(to: &profile) { return }
        applyDurationBonus(to: &profile)
    }

    private func applyPrimaryStat(to profile: inout CombatModifierProfile) -> Bool {
        switch self {
        case let .strength(amount):
            profile.statBonuses.strength += amount
        case let .agility(amount):
            profile.statBonuses.agility += amount
        case let .toughness(amount):
            profile.statBonuses.toughness += amount
        case let .intellect(amount):
            profile.statBonuses.intellect += amount
        case let .wisdom(amount):
            profile.statBonuses.wisdom += amount
        default:
            return false
        }
        return true
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

    private func applyCombatBonus(to profile: inout CombatModifierProfile) -> Bool {
        switch self {
        case let .damageDealt(keyword, amount):
            profile.damageDealtBonus[keyword, default: 0] += amount
        case let .healthRestored(amount):
            profile.healthRestoredBonus += amount
        case let .leechGrantedPercent(amount):
            profile.leechGrantedBonus += amount
        case let .leechHealing(amount):
            profile.leechHealingBonus += amount
        case let .goldGained(amount):
            profile.goldGainedBonus += amount
        case let .blockGranted(amount):
            profile.blockGrantedBonus += amount
        case let .armorGrantedPercent(amount):
            profile.armorGrantedBonus += amount
        case let .damageTakenPercent(keyword, amount):
            profile.damageTakenReduction[keyword, default: 0] += amount
        case let .petDamageDealt(amount):
            profile.petDamageDealtBonus += amount
        default:
            return false
        }
        return true
    }

    private func applyDurationBonus(to profile: inout CombatModifierProfile) {
        switch self {
        case let .blockDuration(amount):
            profile.blockDurationBonus += amount
        case let .armorDuration(amount):
            profile.armorDurationBonus += amount
        case let .leechDuration(amount):
            profile.leechDurationBonus += amount
        case let .bleedDuration(amount):
            profile.bleedDurationBonus += amount
        default:
            break
        }
    }
}
