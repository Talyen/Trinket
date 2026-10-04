import Foundation
import TrinketContent
import TrinketCore

public struct HomesteadEffectLine: Identifiable, Equatable, Sendable {
    public enum Key: Hashable, Sendable {
        case modifier(AffixModifier, companion: Bool)
        case astralFind
        case forgeAstralOdds
        case goldFind(percent: Bool)
        case experience(percent: Bool)
        case gemsFind(percent: Bool)
        case production(HomesteadResource)
    }

    public let id: Key
    public let label: String
    public let value: String
    public let resource: HomesteadResource?

    public static func lines(for tier: HomesteadNodeTier, nodeID: HomesteadNodeID? = nil) -> [Self] {
        let bonus = tier.combatBonus
        var lines = bonus.heroModifiers.map { line(for: $0, companion: false) }
        lines += bonus.companionModifiers
            .filter { !bonus.heroModifiers.contains($0) }
            .map { line(for: $0, companion: true) }
        if bonus.astralChanceBonusPercent != 0 {
            lines.append(Self(
                id: .astralFind,
                label: "Astral drop rates",
                value: "\(bonus.astralChanceBonusPercent)%",
                resource: nil,
            ))
        }
        if nodeID == .blacksmithForge {
            let forgeBonus = BlacksmithRecipe.astralWeightBonusPercent(blacksmithTier: tier.tier)
            if forgeBonus > 0 {
                lines.append(Self(
                    id: .forgeAstralOdds,
                    label: "Forge Astral odds",
                    value: "\(forgeBonus)%",
                    resource: nil,
                ))
            }
        }
        lines += rewardLines(for: bonus)
        for production in tier.production {
            lines.append(Self(
                id: .production(production.resource),
                label: production.resource.displayName,
                value: production.quantity.formatted(),
                resource: production.resource,
            ))
        }
        return lines
    }

    private static func rewardLines(for bonus: HomesteadTierCombatBonus) -> [Self] {
        let rewards: [(Key, String, String, Bool)] = [
            (.goldFind(percent: true), "Gold found", "\(bonus.goldFindPercent)%", bonus.goldFindPercent != 0),
            (.goldFind(percent: false), "Gold found", "\(bonus.goldFindFlat)", bonus.goldFindFlat > 0),
            (.experience(percent: true), "Experience", "\(bonus.experienceBonusPercent)%", bonus.experienceBonusPercent > 0),
            (.experience(percent: false), "Experience", "\(bonus.experienceBonus)", bonus.experienceBonus > 0),
            (.gemsFind(percent: true), "Gems found", "\(bonus.gemsFindPercent)%", bonus.gemsFindPercent > 0),
            (.gemsFind(percent: false), "Gems in encounter rewards containing Gems", "\(bonus.gemsFindBonus)", bonus.gemsFindBonus > 0),
        ]
        return rewards.compactMap { key, label, value, enabled in
            enabled ? Self(id: key, label: label, value: value, resource: nil) : nil
        }
    }

    private static func line(for modifier: AffixModifier, companion: Bool) -> Self {
        let label = label(for: modifier)
        let value = modifier.numericValue * (modifier.isPercent ? 100 : 1)
        let formatted = value.formatted(.number.precision(.fractionLength(0 ... 2)))
        let scopedLabel: String = if companion, !label.hasPrefix("Companion ") {
            "Companion \(label)"
        } else if !companion, label == "Health" {
            "Hero \(label)"
        } else {
            label
        }
        return Self(
            id: .modifier(modifier.mapInt { _ in 0 }.mapPercent { _ in 0 }, companion: companion),
            label: scopedLabel,
            value: formatted + (modifier.isPercent ? "%" : ""),
            resource: nil,
        )
    }

    public var description: String {
        switch id {
        case .production:
            "Produce \(value) \(label) per Day"
        case .astralFind: "Astral drop rates rise by \(value)"
        case .forgeAstralOdds: "Astral forge odds rise by \(value)"
        case .goldFind: "Find \(value) more Gold"
        case .experience: "Gain \(value) more Experience"
        case .gemsFind: "Find \(value) more Gems"
        case let .modifier(modifier, companion):
            switch modifier {
            case .maximumHealthPercent:
                companion ? "Companion Health rises by \(value)" : "Increase Hero Health by \(value)"
            case let .damageDealtPercent(keyword, _): "Increase \(keyword.rawValue) damage by \(value)"
            case let .damageTakenPercent(keyword, _): "Take \(value) less \(keyword.rawValue) damage"
            case .criticalDamagePercent: "Increase Critical damage by \(value)"
            case .healthRestoredPercent: "Restore \(value) more Health"
            case .manaRestoredPercent: "Restore \(value) more Mana"
            case .leechHealingPercent: "Leech restores \(value) more Health"
            case .blockGainedPercent: "Gain \(value) more Block"
            case .companionDamageDealtPercent: "Companion damage rises by \(value)"
            case .dodgeChanceBonus: "\(label) chance \(displayValue)"
            case .rangedDamageDealtPercent: "Bow and Crossbow damage \(displayValue)"
            default: "\(label) \(displayValue)"
            }
        }
    }

    public var displayValue: String {
        if resource != nil {
            return "+" + value
        }
        if case let .modifier(modifier, _) = id {
            switch modifier {
            case .damageTakenPercent, .damageTakenFlat, .incomingDamageReductionPercent:
                return "−" + value
            default: break
            }
        }
        return "+" + value
    }

    private static func label(for modifier: AffixModifier) -> String {
        switch modifier {
        case .criticalDamage, .criticalDamagePercent: "Critical damage"
        case .manaRestored, .manaRestoredPercent: "Mana restored"
        case .maximumHealth, .maximumHealthPercent: "Health"
        case .maximumMana: "Mana"
        case let .damageDealt(keyword, _), let .damageDealtPercent(keyword, _): "\(keyword.rawValue) damage"
        case .poisonDamageDealtPercent: "Poison damage"
        case .healthRestored, .healthRestoredPercent: "Health restored"
        case .leechGainedPercent: "Leech gained"
        case .leechHealing, .leechHealingPercent: "Leech healing"
        case .goldGained, .goldGainedPercent: "Gold gained"
        case .blockGained, .blockGainedPercent: "Block gained"
        case .bleedDuration: "Bleed duration (turns)"
        case let .damageTakenPercent(keyword, _), let .damageTakenFlat(keyword, _), let .damageTakenVulnerability(keyword, _):
            "\(keyword.rawValue) damage taken"
        case .companionDamageDealt, .companionDamageDealtPercent: "Companion damage"
        case .companionPhysicalDamageDealt: "Companion Physical damage"
        case .companionBleedDamageDealt: "Companion Bleed damage"
        case .outgoingDamagePercent: "Party damage"
        case .incomingDamageReductionPercent: "Party damage taken"
        case .dodgeChanceBonus: "Dodge"
        case .rangedDamageDealt, .rangedDamageDealtPercent: "Bow and Crossbow damage"
        case .maximumManaPercent: "Mana"
        case .startBattleBlock: "Starting Block"
        case .attackLeechPercent: "Attack Leech"
        case .attackBlockRemoval: "Block removed on attack"
        case .attackPurgeCount: "Attack Purge"
        }
    }
}
