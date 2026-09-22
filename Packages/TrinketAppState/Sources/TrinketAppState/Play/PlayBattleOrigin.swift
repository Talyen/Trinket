import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

public enum PlayBattleOrigin: Hashable, Sendable {
    case journey(stageID: String)
    case spire(spireID: SpireID, floor: Int)
    case labyrinth(nodeID: String)
    case contract(offerID: String)
    case voyage(runID: String, nodeID: String)

    public var runKey: BattleRunKey {
        switch self {
        case let .journey(stageID):
            BattleRunKey("journey|\(stageID)")
        case let .spire(spireID, floor):
            BattleRunKey("spire|\(spireID.rawValue)|\(floor)")
        case let .labyrinth(nodeID):
            BattleRunKey("labyrinth|\(nodeID)")
        case let .voyage(runID, nodeID):
            BattleRunKey("voyage|\(runID)|\(nodeID)")
        case let .contract(offerID):
            BattleRunKey("contract|\(offerID)")
        }
    }

    /// Owner scope for prepared-run pruning: one mode's pruning must never
    /// destroy a sibling mode's warms.
    var isLabyrinth: Bool {
        if case .labyrinth = self {
            return true
        }
        return false
    }
}

@MainActor
struct PlayBattleRoute {
    let origin: PlayBattleOrigin
    let complete: (
        BattleRunConfiguration,
        BattlePresentationContext?,
        BattleRewardSettlement,
        [ResourceAmount]?,
        BattleLootResult?,
    ) -> BattleCompletionResult

    /// Shared persist-transaction wrapper for mode battle routes. Each mode
    /// passes only its completion call; idempotency mapping stays single-owned
    /// here (duplicate deliveries grant nothing further, failed writes retry).
    static func makeModeRoute(
        origin: PlayBattleOrigin,
        logging: String,
        playerSave: PlayerSaveStore,
        complete: @escaping (
            BattleRunConfiguration,
            BattlePresentationContext?,
            BattleRewardSettlement,
            [ResourceAmount]?,
            BattleLootResult?,
            inout PlayerSave,
        ) -> EncounterCompletion,
    ) -> Self {
        Self(origin: origin) { configuration, presentation, award, materialRewards, loot in
            let transaction = playerSave.persistTransaction(logging: logging) { save -> Result<
                EncounterCompletion,
                PlayCompletionFailure,
            > in
                switch complete(configuration, presentation, award, materialRewards, loot, &save) {
                case .completed: return .success(.completed)
                case .alreadyCompleted, .unavailable: return .failure(.unavailable)
                }
            }
            return Self.completionResult(transaction)
        }
    }

    static func matches(_ route: Self?, runKey: BattleRunKey?, missingLog: String) -> Bool {
        guard let runKey else { return route == nil }
        guard let route, route.origin.runKey == runKey else {
            appStateLogger.error("\(missingLog, privacy: .public)")
            return false
        }
        return true
    }

    /// Single idempotency mapping for mode battle routes. Duplicate deliveries
    /// (double-tap, silent retry, deferred flush) report `.unavailable` and
    /// grant nothing further instead of paying twice; only a failed write is
    /// retryable as `.persistenceFailed`.
    static func completionResult(_ completion: EncounterCompletion) -> BattleCompletionResult {
        switch completion {
        case .completed: .completed
        case .alreadyCompleted, .unavailable: .unavailable
        }
    }

    static func completionResult(
        _ transaction: SaveTransactionResult<EncounterCompletion, PlayCompletionFailure>,
    ) -> BattleCompletionResult {
        switch transaction {
        case let .committed(completion): completionResult(completion)
        case .rejected: .unavailable
        case .persistFailed: .persistenceFailed
        }
    }
}

/// Rejection for mode completion transactions: the encounter was already
/// claimed or is no longer available, so the write is intentionally skipped.
enum PlayCompletionFailure: Error {
    case unavailable
}

@MainActor
struct PlayBattleRunRegistration {
    let route: PlayBattleRoute
    let launch: BattleLaunchAssembly
    var presentation: BattlePresentationContext {
        launch.presentation
    }

    var universalModifiers: [AffixModifier] {
        launch.universalModifiers
    }
}
