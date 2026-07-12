import Foundation
import TrinketCore

public enum AffixModifier: Equatable, Hashable, Sendable {
    case strength(Int)
    case agility(Int)
    case toughness(Int)
    case intellect(Int)
    case wisdom(Int)
    case maximumHealth(Int)
    case maximumMana(Int)
    case damageDealt(Keyword, Int)
    case healthRestored(Int)
    case leechGainedPercent(Double)
    case leechHealing(Int)
    case goldGained(Int)
    case blockGained(Int)
    case armorGained(Int)
    case leechDuration(Int)
    case bleedDuration(Int)
    case damageTakenPercent(Keyword, Double)
    case damageTakenFlat(Keyword, Int)
    case damageTakenVulnerability(Keyword, Double)
    case petDamageDealt(Int)
    case manaCostReductionPercent(Double)
}
