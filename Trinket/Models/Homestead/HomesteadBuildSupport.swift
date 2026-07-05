import TrinketContent
import TrinketPersistence

enum HomesteadBuildSupport {
    enum Outcome: Equatable {
        case success
        case failed(message: String)
    }

    static func buildOrUpgrade(
        _ definition: HomesteadNodeDefinition,
        homestead: PlayerHomesteadStore,
        roster: PlayerRosterStore
    ) -> Outcome {
        switch homestead.buildOrUpgrade(definition, roster: roster) {
        case .success:
            return .success
        case .insufficientResources:
            return .failed(message: "Not enough resources to build or upgrade this project.")
        case .persistFailed:
            return .failed(message: "Couldn't save homestead progress. Try again.")
        }
    }
}
