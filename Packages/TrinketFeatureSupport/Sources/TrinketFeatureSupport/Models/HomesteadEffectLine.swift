import Foundation
import TrinketContent
import TrinketCore

public struct HomesteadEffectLine: Identifiable, Equatable, Sendable {
    public enum Key: Hashable, Sendable {
        case modifier(AffixModifier, companion: Bool)
        case astralFind
        case goldFind
        case production(HomesteadResource)
    }

    public let id: Key
    public let label: String
    public let value: String
    public let resource: HomesteadResource?

    public static func lines(for tier: HomesteadNodeTier) -> [Self] {
        let bonus = tier.combatBonus
        var lines = bonus.heroModifiers.map { line(for: $0, companion: false) }
        lines += bonus.companionModifiers
            .filter { !bonus.heroModifiers.contains($0) }
            .map { line(for: $0, companion: true) }
        if bonus.astralChanceBonusPercent != 0 {
            lines.append(Self(
                id: .astralFind,
                label: "Astral finds",
                value: "\(bonus.astralChanceBonusPercent)%",
                resource: nil,
            ))
        }
        if bonus.goldFindPercent != 0 {
            lines.append(Self(
                id: .goldFind,
                label: "Gold finds",
                value: "\(bonus.goldFindPercent)%",
                resource: nil,
            ))
        }
        if let production = tier.production {
            lines.append(Self(
                id: .production(production.resource),
                label: production.resource.displayName,
                value: production.quantity.formatted(),
                resource: production.resource,
            ))
        }
        return lines
    }

    private static func line(for modifier: AffixModifier, companion: Bool) -> Self {
        let label = label(for: modifier)
        let value = modifier.numericValue * (modifier.isPercent ? 100 : 1)
        let formatted = value.formatted(.number.precision(.fractionLength(0 ... 2)))
        let scopedLabel = companion ? "Companion \(label)" : label
        return Self(
            id: .modifier(modifier.mapInt { _ in 0 }.mapPercent { _ in 0 }, companion: companion),
            label: scopedLabel,
            value: formatted + (modifier.isPercent ? "%" : ""),
            resource: nil,
        )
    }

    public var displayValue: String {
        if resource != nil {
            return value
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

    // swiftlint:disable:next cyclomatic_complexity - Exhaustive modifier labels must reject missing cases at compile time
    private static func label(for modifier: AffixModifier) -> String {
        switch modifier {
        case .maximumHealth: "Health"
        case .maximumMana: "Mana"
        case let .damageDealt(keyword, _): "\(keyword.rawValue) damage dealt"
        case .poisonDamageDealtPercent: "Poison damage dealt"
        case .healthRestored: "Health restored"
        case .leechGainedPercent: "Leech gained"
        case .leechHealing: "Leech healing"
        case .goldGained, .goldGainedPercent: "Gold gained"
        case .blockGained: "Block gained"
        case .bleedDuration: "Bleed duration (turns)"
        case let .damageTakenPercent(keyword, _), let .damageTakenFlat(keyword, _), let .damageTakenVulnerability(keyword, _):
            "\(keyword.rawValue) damage taken"
        case .companionDamageDealt: "Companion damage"
        case .companionBleedDamageDealt: "Companion Bleed damage"
        case .outgoingDamagePercent: "Party damage"
        case .incomingDamageReductionPercent: "Party damage taken"
        case .dodgeChanceBonus: "Dodge"
        }
    }
}
