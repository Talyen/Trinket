import Foundation

public enum BattleOutcomeResolver {
    public static func resolve(isPartyDefeated: Bool, isEnemyDefeated: Bool) -> BattleSimulationOutcome? {
        if isEnemyDefeated, isPartyDefeated { return .victory }
        if isPartyDefeated { return .defeat }
        if isEnemyDefeated { return .victory }
        return nil
    }
}
