import Foundation
import TrinketBattleRuntime
import TrinketPersistence

/// Standard protocol implemented by Play mode controllers in `TrinketAppState`.
///
/// Ensures consistent ownership of persistence transactions, battle preparation,
/// and session lifecycle across Journey, Labyrinth, Spires, and Encounter modes.
@MainActor
public protocol PlayModeProtocol: AnyObject {
    var playerSave: PlayerSaveStore { get }
    var battle: any BattleRuntime { get }
}

extension PlayModeProtocol {
    /// Executes a batch mutation on `playerSave` with consistent error handling.
    @discardableResult
    func performModeMutation<T>(
        actionName: String,
        mutation: (inout PlayerSave) throws -> T
    ) -> T? {
        do {
            var result: T?
            var mutationError: Error?
            try playerSave.performBatchMutation { save in
                do {
                    result = try mutation(&save)
                } catch {
                    mutationError = error
                }
            }
            if let mutationError {
                throw mutationError
            }
            return result
        } catch {
            appStateLogger.error(
                "Failed mode mutation (\(actionName, privacy: .public)): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}
