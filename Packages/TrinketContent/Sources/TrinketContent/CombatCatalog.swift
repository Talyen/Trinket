import Foundation
import TrinketCore

/// Injectable combat content lookups. Battle rules resolve builds through this seam
/// instead of calling `GameContent` directly.
public protocol CombatCatalog: Sendable {
    func trait(forCombatantID: String) -> CombatantTraitDefinition?
    func positiveTrait(for enemy: Enemy) -> CombatantTraitDefinition?
    func negativeTrait(for enemy: Enemy) -> CombatantTraitDefinition?
    func itemAffixDefinition(id: String) -> ItemAffixDefinition?
    func enemy(matching id: String) -> Enemy?
}

public struct GameContentCombatCatalog: CombatCatalog {
    public init() {}

    public func trait(forCombatantID combatantID: String) -> CombatantTraitDefinition? {
        GameContent.trait(forCombatantID: combatantID)
    }

    public func positiveTrait(for enemy: Enemy) -> CombatantTraitDefinition? {
        GameContent.positiveTrait(for: enemy)
    }

    public func negativeTrait(for enemy: Enemy) -> CombatantTraitDefinition? {
        GameContent.negativeTrait(for: enemy)
    }

    public func itemAffixDefinition(id: String) -> ItemAffixDefinition? {
        GameContent.itemAffixDefinitions.first { $0.id == id }
    }

    public func enemy(matching id: String) -> Enemy? {
        GameContent.enemy(matching: id)
    }
}

public extension CombatCatalog {
    func traitDisplayName(forCombatantID combatantID: String) -> String {
        trait(forCombatantID: combatantID)?.name ?? "Trait"
    }

    func enemyTraitDisplayName(for combatant: Combatant) -> String {
        if let enemy = enemy(matching: combatant.id),
           let positiveTrait = positiveTrait(for: enemy) {
            return positiveTrait.name
        }
        return traitDisplayName(forCombatantID: combatant.id)
    }
}
