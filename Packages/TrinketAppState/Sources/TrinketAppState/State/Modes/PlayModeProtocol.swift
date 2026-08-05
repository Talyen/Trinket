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
