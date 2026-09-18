import BattleEngine
import Foundation
import TrinketContent
import TrinketPersistence

/// A resolved enemy plus the level it should fight at.
public typealias ScaledEncounter = (combatant: Combatant, level: Int)

/// Preparation cache key for single-battle modes (Journey, Spires).
/// Both warm at most one run; the run key identifies the battle 1:1 with the
/// mode's battle origin (stage ID, spire + floor), so cache behavior is unchanged.
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

    /// One home for per-mode encounter math. The level curves stay distinct by
    /// design (contracts track party level, journey/labyrinth blend authored
    /// and party levels, spires stay fixed); only the lookup-and-scale tail
    /// is shared.
    static func contractEncounter(for offer: ContractOffer, partyAverageLevel: Int) -> ScaledEncounter? {
        scaledEncounter(
            enemyID: offer.enemyID,
            level: EncounterLevelResolver.contractEnemyLevel(
                difficulty: offer.difficulty,
                partyAverageLevel: partyAverageLevel,
            ),
        )
    }

    static func journeyEncounter(for stage: Stage, worldSeed: UInt64, partyAverageLevel: Int) -> ScaledEncounter? {
        guard let chapter = GameContent.chapters.first(where: { $0.id == stage.chapterID })
        else { return nil }
        return scaledEncounter(
            enemyID: stage.resolvedBattleEnemyID(worldSeed: worldSeed),
            level: EncounterLevelResolver.campaignAdjusted(
                EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter),
                partyAverageLevel: partyAverageLevel,
            ),
        )
    }

    static func labyrinthEncounter(for node: LabyrinthNode, partyAverageLevel: Int) -> ScaledEncounter? {
        scaledEncounter(
            enemyID: node.enemyID,
            level: EncounterLevelResolver.labyrinthAdjusted(
                EncounterLevelResolver.labyrinthEnemyLevel(for: node),
                partyAverageLevel: partyAverageLevel,
            ),
        )
    }

    static func spireEncounter(for floor: SpireFloor) -> ScaledEncounter? {
        scaledEncounter(
            enemyID: floor.enemyID,
            level: EncounterLevelResolver.spireEnemyLevel(for: floor),
        )
    }
}
