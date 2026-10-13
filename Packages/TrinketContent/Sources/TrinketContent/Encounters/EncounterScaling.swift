import TrinketCore

/// Mode policy shared by battle previews, launch, reward fallbacks, and simulations.
/// Authored levels come from `EncounterLevelResolver`; party adjustment and power
/// profile selection stay together here.
public enum EncounterScaling: Sendable {
    case journey(authoredLevel: Int)
    case spire(authoredLevel: Int)
    case labyrinth(authoredLevel: Int)
    case contract(ContractDifficulty)
    case voyage(VoyageDifficulty)

    public struct Resolution: Equatable, Sendable {
        public let level: Int
        public let profile: EnemyPowerCurve.Profile
    }

    public func resolve(partyAverageLevel: Int) -> Resolution {
        switch self {
        case let .journey(authoredLevel):
            Resolution(
                level: EncounterLevelResolver.campaignAdjusted(authoredLevel, partyAverageLevel: partyAverageLevel),
                profile: .standard,
            )
        case let .spire(authoredLevel):
            Resolution(level: max(1, authoredLevel), profile: .spire)
        case let .labyrinth(authoredLevel):
            Resolution(
                level: EncounterLevelResolver.labyrinthAdjusted(authoredLevel, partyAverageLevel: partyAverageLevel),
                profile: .standard,
            )
        case let .contract(difficulty):
            Resolution(
                level: EncounterLevelResolver.contractEnemyLevel(difficulty: difficulty, partyAverageLevel: partyAverageLevel),
                profile: difficulty == .easy ? .recovery : .standard,
            )
        case let .voyage(difficulty):
            Resolution(level: difficulty.encounterLevel(partyLevel: partyAverageLevel), profile: .standard)
        }
    }
}
