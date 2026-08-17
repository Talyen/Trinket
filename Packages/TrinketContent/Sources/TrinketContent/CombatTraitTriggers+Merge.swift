import Foundation
import TrinketCore

public extension CombatTraitTriggers {
    mutating func merge(_ other: Self) {
        ensureUnique()
        storage.fields.damage.merge(other.storage.fields.damage)
        storage.fields.attack.merge(other.storage.fields.attack)
        storage.fields.block.merge(other.storage.fields.block)
        storage.fields.mitigation.merge(other.storage.fields.mitigation)
        storage.fields.dot.merge(other.storage.fields.dot)
        storage.fields.control.merge(other.storage.fields.control)
        storage.fields.dodge.merge(other.storage.fields.dodge)
        storage.fields.mana.merge(other.storage.fields.mana)
        storage.fields.gold.merge(other.storage.fields.gold)
        storage.fields.healing.merge(other.storage.fields.healing)
        storage.fields.revival.merge(other.storage.fields.revival)
        storage.fields.cleanse.merge(other.storage.fields.cleanse)
        storage.fields.enemyTurn.merge(other.storage.fields.enemyTurn)
        storage.fields.onHit.merge(other.storage.fields.onHit)
    }

    func merged(with other: Self) -> Self {
        var copy = self
        copy.merge(other)
        return copy
    }
}
