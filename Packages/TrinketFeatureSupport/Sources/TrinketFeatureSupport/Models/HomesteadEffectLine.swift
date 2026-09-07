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
    public let prefix: String
    public let value: String
    public let suffix: String
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
                prefix: "Find",
                value: "\(bonus.astralChanceBonusPercent)%",
                suffix: "more Astral items",
                resource: nil,
            ))
        }
        if bonus.goldFindPercent != 0 {
            lines.append(Self(
                id: .goldFind,
                prefix: "Find",
                value: "\(bonus.goldFindPercent)%",
                suffix: "more",
                resource: .gold,
            ))
        }
        if let production = tier.production {
            lines.append(Self(
                id: .production(production.resource),
                prefix: "Produces",
                value: production.quantity.formatted(),
                suffix: "per day",
                resource: production.resource,
            ))
        }
        return lines
    }

    private static func line(for modifier: AffixModifier, companion: Bool) -> Self {
        let copy = copy(for: modifier)
        let value = modifier.numericValue * (modifier.isPercent ? 100 : 1)
        let formatted = value.formatted(.number.precision(.fractionLength(0 ... 2)))
        let prefix: String = if companion, case .dodgeChanceBonus = modifier {
            "Increase Companion Dodge by"
        } else {
            companion ? "Companion: \(copy.prefix)" : copy.prefix
        }
        return Self(
            id: .modifier(modifier.mapInt { _ in 0 }.mapPercent { _ in 0 }, companion: companion),
            prefix: prefix,
            value: formatted + (modifier.isPercent ? "%" : ""),
            suffix: copy.suffix,
            resource: copy.resource,
        )
    }

    // swiftlint:disable:next cyclomatic_complexity - Exhaustive modifier copy must reject missing cases at compile time
    private static func copy(for modifier: AffixModifier) -> (prefix: String, suffix: String, resource: HomesteadResource?) {
        switch modifier {
        case .maximumHealth:
            ("Increase Health by", "", nil)
        case .maximumMana:
            ("Increase Mana by", "", nil)
        case let .damageDealt(keyword, _):
            ("Increase \(keyword.rawValue) damage dealt by", "", nil)
        case .poisonDamageDealtPercent:
            ("Increase Poison damage dealt by", "", nil)
        case .healthRestored:
            ("Restore", "additional Health", nil)
        case .leechGainedPercent:
            ("Increase Leech gained by", "", nil)
        case .leechHealing:
            ("Increase Leech healing by", "", nil)
        case .goldGained:
            ("Gain", "additional", .gold)
        case .goldGainedPercent:
            ("Gain", "more", .gold)
        case .blockGained:
            ("Gain", "additional Block", nil)
        case .bleedDuration:
            ("Extend Bleed by", "turns", nil)
        case let .damageTakenPercent(keyword, _):
            ("Reduce \(keyword.rawValue) damage taken by", "", nil)
        case let .damageTakenFlat(keyword, _):
            ("Reduce \(keyword.rawValue) damage taken by", "", nil)
        case let .damageTakenVulnerability(keyword, _):
            ("Increase \(keyword.rawValue) damage taken by", "", nil)
        case .companionDamageDealt:
            ("Increase Companion damage dealt by", "", nil)
        case .companionBleedDamageDealt:
            ("Increase Companion Bleed damage dealt by", "", nil)
        case .outgoingDamagePercent:
            ("Increase Party damage by", "", nil)
        case .incomingDamageReductionPercent:
            ("Reduce Party damage taken by", "", nil)
        case .dodgeChanceBonus:
            ("Increase Dodge by", "", nil)
        }
    }
}

public struct HomesteadEffectComparison: Identifiable, Equatable, Sendable {
    public let id: HomesteadEffectLine.Key
    public let current: HomesteadEffectLine?
    public let proposed: HomesteadEffectLine?

    public static func lines(current: HomesteadNodeTier?, proposed: HomesteadNodeTier) -> [Self] {
        let currentLines = current.map { HomesteadEffectLine.lines(for: $0) } ?? []
        let proposedLines = HomesteadEffectLine.lines(for: proposed)
        var comparisons = proposedLines.map { line in
            Self(id: line.id, current: currentLines.first { $0.id == line.id }, proposed: line)
        }
        comparisons += currentLines.filter { currentLine in
            !proposedLines.contains { $0.id == currentLine.id }
        }.map { Self(id: $0.id, current: $0, proposed: nil) }
        return comparisons
    }
}
