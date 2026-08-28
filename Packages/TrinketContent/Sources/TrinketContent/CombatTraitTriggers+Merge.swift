import Foundation
import TrinketCore

public extension CombatTraitTriggers {
    mutating func merge(_ other: Self) {
        ensureUnique()
        storage.value.damage.merge(other.storage.value.damage)
        storage.value.attack.merge(other.storage.value.attack)
        storage.value.block.merge(other.storage.value.block)
        storage.value.mitigation.merge(other.storage.value.mitigation)
        storage.value.dot.merge(other.storage.value.dot)
        storage.value.control.merge(other.storage.value.control)
        storage.value.dodge.merge(other.storage.value.dodge)
        storage.value.mana.merge(other.storage.value.mana)
        storage.value.gold.merge(other.storage.value.gold)
        storage.value.healing.merge(other.storage.value.healing)
        storage.value.revival.merge(other.storage.value.revival)
        storage.value.cleanse.merge(other.storage.value.cleanse)
        storage.value.enemyTurn.merge(other.storage.value.enemyTurn)
        storage.value.onHit.merge(other.storage.value.onHit)
    }

    func merged(with other: Self) -> Self {
        var copy = self
        copy.merge(other)
        return copy
    }
}
