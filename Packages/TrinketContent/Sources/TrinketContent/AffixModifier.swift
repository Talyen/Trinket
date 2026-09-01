import Foundation
import TrinketCore

public enum AffixModifier: Equatable, Hashable, Codable, Sendable {
    case maximumHealth(Int)
    case maximumMana(Int)
    case damageDealt(Keyword, Int)
    case poisonDamageDealtPercent(Double)
    case healthRestored(Int)
    case leechGainedPercent(Double)
    case leechHealing(Int)
    case goldGained(Int)
    case goldGainedPercent(Double)
    case blockGained(Int)
    case bleedDuration(Int)
    case damageTakenPercent(Keyword, Double)
    case damageTakenFlat(Keyword, Int)
    case damageTakenVulnerability(Keyword, Double)
    case companionDamageDealt(Int)
    case companionBleedDamageDealt(Int)
    case outgoingDamagePercent(Double)
    case incomingDamageReductionPercent(Double)
    case dodgeChanceBonus(Double)
}

public extension AffixModifier {
    var isPercent: Bool {
        switch self {
        case .poisonDamageDealtPercent,
             .leechGainedPercent,
             .goldGainedPercent,
             .damageTakenPercent,
             .damageTakenVulnerability,
             .outgoingDamagePercent,
             .incomingDamageReductionPercent,
             .dodgeChanceBonus:
            true
        default:
            false
        }
    }

    var numericValue: Double {
        switch self {
        case let .maximumHealth(v),
             let .maximumMana(v),
             let .damageDealt(_, v),
             let .healthRestored(v),
             let .leechHealing(v),
             let .goldGained(v),
             let .blockGained(v),
             let .bleedDuration(v),
             let .damageTakenFlat(_, v),
             let .companionDamageDealt(v),
             let .companionBleedDamageDealt(v):
            Double(v)
        case let .poisonDamageDealtPercent(v),
             let .leechGainedPercent(v),
             let .goldGainedPercent(v),
             let .damageTakenPercent(_, v),
             let .damageTakenVulnerability(_, v),
             let .outgoingDamagePercent(v),
             let .incomingDamageReductionPercent(v),
             let .dodgeChanceBonus(v):
            v
        }
    }

    func mapInt(_ transform: (Int) -> Int) -> AffixModifier {
        switch self {
        case let .maximumHealth(v): .maximumHealth(transform(v))
        case let .maximumMana(v): .maximumMana(transform(v))
        case let .damageDealt(kw, v): .damageDealt(kw, transform(v))
        case let .healthRestored(v): .healthRestored(transform(v))
        case let .leechHealing(v): .leechHealing(transform(v))
        case let .goldGained(v): .goldGained(transform(v))
        case let .blockGained(v): .blockGained(transform(v))
        case let .bleedDuration(v): .bleedDuration(transform(v))
        case let .damageTakenFlat(kw, v): .damageTakenFlat(kw, transform(v))
        case let .companionDamageDealt(v): .companionDamageDealt(transform(v))
        case let .companionBleedDamageDealt(v): .companionBleedDamageDealt(transform(v))
        default: self
        }
    }

    func mapPercent(_ transform: (Double) -> Double) -> AffixModifier {
        switch self {
        case let .poisonDamageDealtPercent(v): .poisonDamageDealtPercent(transform(v))
        case let .leechGainedPercent(v): .leechGainedPercent(transform(v))
        case let .goldGainedPercent(v): .goldGainedPercent(transform(v))
        case let .damageTakenPercent(kw, v): .damageTakenPercent(kw, transform(v))
        case let .damageTakenVulnerability(kw, v): .damageTakenVulnerability(kw, transform(v))
        case let .outgoingDamagePercent(v): .outgoingDamagePercent(transform(v))
        case let .incomingDamageReductionPercent(v): .incomingDamageReductionPercent(transform(v))
        case let .dodgeChanceBonus(v): .dodgeChanceBonus(transform(v))
        default: self
        }
    }

    func bumped(intDelta: Int, percentDelta: Double) -> AffixModifier? {
        if isPercent {
            let old = numericValue
            let new = old + percentDelta
            guard percentDelta > 0 || old > 0.01 + 1e-9 else { return nil }
            return mapPercent { _ in new }
        }
        let old = Int(numericValue)
        let new = old + intDelta
        guard intDelta > 0 || old > 1 else { return nil }
        return mapInt { _ in new }
    }
}
