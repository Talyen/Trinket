import Foundation
import TrinketContent
import TrinketCore

public struct BattleMatchup: Equatable, Hashable {
    public let hero: Combatant
    public let companion: Combatant
    public let enemy: Combatant

    public init(hero: Combatant, companion: Combatant, enemy: Combatant? = nil) {
        self.hero = hero
        self.companion = companion
        self.enemy = enemy ?? Enemy.fallbackCombatant
    }

    public func combatant(for participant: BattleParticipant) -> Combatant {
        switch participant {
        case .hero: hero
        case .companion: companion
        case .enemy: enemy
        }
    }
}

public enum BattleSimulationOutcome: Equatable, Sendable {
    case victory
    case defeat

    public static func resolve(isPartyDefeated: Bool, isEnemyDefeated: Bool) -> BattleSimulationOutcome? {
        if isEnemyDefeated, isPartyDefeated {
            return .victory
        }
        if isPartyDefeated {
            return .defeat
        }
        if isEnemyDefeated {
            return .victory
        }
        return nil
    }
}
