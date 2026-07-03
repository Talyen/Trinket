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
    case leechGrantedPercent(Double)
    case leechHealing(Int)
    case goldGained(Int)
    case blockGranted(Int)
    case armorGrantedPercent(Double)
    case blockDuration(Int)
    case armorDuration(Int)
    case leechDuration(Int)
    case bleedDuration(Int)
    case damageTakenPercent(Keyword, Double)
}
