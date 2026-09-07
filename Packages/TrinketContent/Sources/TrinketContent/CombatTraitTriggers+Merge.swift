import Foundation
import TrinketCore

public extension CombatTraitTriggers {
    mutating func merge(_ other: Self) {
        fields.damage.merge(other.fields.damage)
        fields.attack.merge(other.fields.attack)
        fields.block.merge(other.fields.block)
        fields.mitigation.merge(other.fields.mitigation)
        fields.dot.merge(other.fields.dot)
        fields.control.merge(other.fields.control)
        fields.dodge.merge(other.fields.dodge)
        fields.mana.merge(other.fields.mana)
        fields.gold.merge(other.fields.gold)
        fields.healing.merge(other.fields.healing)
        fields.revival.merge(other.fields.revival)
        fields.cleanse.merge(other.fields.cleanse)
        fields.enemyTurn.merge(other.fields.enemyTurn)
        fields.onHit.merge(other.fields.onHit)
    }

    func merged(with other: Self) -> Self {
        var copy = self
        copy.merge(other)
        return copy
    }
}
