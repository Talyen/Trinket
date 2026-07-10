import Foundation
import TrinketContent
import TrinketCore

public struct BattleMatchup: Equatable, Hashable {
    public let hero: Combatant
    public let pet: Combatant
    public let enemy: Combatant

    public init(hero: Combatant, pet: Combatant, enemy: Combatant? = nil) {
        self.hero = hero
        self.pet = pet
        self.enemy = enemy ?? Enemy.fallbackCombatant
    }

    public func combatant(for participant: BattleParticipant) -> Combatant {
        switch participant {
        case .hero: return hero
        case .pet: return pet
        case .enemy: return enemy
        }
    }
}

public enum BattleSimulationOutcome: Equatable {
    case victory
    case defeat

    public static func resolve(isPartyDefeated: Bool, isEnemyDefeated: Bool) -> BattleSimulationOutcome? {
        if isEnemyDefeated, isPartyDefeated { return .victory }
        if isPartyDefeated { return .defeat }
        if isEnemyDefeated { return .victory }
        return nil
    }
}
