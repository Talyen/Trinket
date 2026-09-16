import BattleEngine
import Foundation
import TrinketContent
import TrinketPersistence

/// A resolved enemy plus the level it should fight at.
public typealias ScaledEncounter = (combatant: Combatant, level: Int)

/// Shared header for transient encounter sessions (shop, mystery).
/// Both sessions expose the same origin/stage/encounter triple; the protocol
/// keeps that mapping in one place instead of drifting per session type.
@MainActor
protocol EncounterSession: AnyObject {
    var stage: Stage { get }
    var origin: PlayEncounterOrigin { get }
    var encounter: EncounterIdentity { get }
    var labyrinthNodeID: String? { get }
}

/// Preparation cache key for single-battle modes (Journey, Spires).
/// Both warm at most one run; the run key identifies the battle 1:1 with the
/// old per-mode keys (stage ID, spire + floor), so cache behavior is unchanged.
struct SingleBattlePreparationInputs: Equatable {
    let runKey: BattleRunKey
    let party: PlayBattlePartySnapshot
    let stageRewardsAlreadyClaimed: Bool
}

enum PlayBattlePreparation {
    static func scaledEncounter(
        enemyID: String?,
        level: Int,
    ) -> ScaledEncounter? {
        guard let enemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID)
        else { return nil }
        return (CombatantLevelScaler.scale(enemy: catalogEnemy, level: level), level)
    }
}
