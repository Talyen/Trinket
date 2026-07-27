public enum BattleSimulationOutcome: Equatable, Sendable {
    case victory
    case defeat

    public static func resolve(
        isPartyDefeated: Bool,
        isEnemyDefeated: Bool
    ) -> Self? {
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
