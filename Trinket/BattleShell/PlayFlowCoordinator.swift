import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

/// Owns play-tab battle orchestration: encounter resolution, configuration assembly,
/// and session hand-off. Persistence and sync remain on `AppState`.
@MainActor
enum PlayFlowCoordinator {
    static func startBattle(
        session: BattleSession,
        stage: Stage,
        roster: PlayerRosterStore,
        inventory: PlayerInventoryStore,
        catalog: CombatCatalog = GameContentCombatCatalog(),
        contentCatalog: PlayerContentCatalog = GameContentPlayerCatalog()
    ) -> StageMapMessage? {
        guard session.activeBattle == nil else { return nil }

        guard let encounter = StageEncounterResolver.resolve(for: stage, catalog: contentCatalog) else {
            return StageMapMessage(title: "Encounter Missing", message: "This stage is not ready yet.")
        }

        session.presentation.preview = nil
        session.activeBattle = ActiveBattleConfiguration.make(
            stageID: stage.id,
            rngSeed: UInt64.random(in: UInt64.min ... UInt64.max),
            hero: roster.activeHero,
            pet: roster.activePet,
            roster: roster,
            inventory: inventory,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: stage.rewards,
            rewardItemNames: rewardItemNames(for: stage.rewards, catalog: contentCatalog),
            catalog: catalog
        )
        session.notifyBattleStarted(stageID: stage.id)
        return nil
    }

    static func restartBattle(
        session: BattleSession,
        roster: PlayerRosterStore,
        inventory: PlayerInventoryStore,
        catalog: CombatCatalog = GameContentCombatCatalog()
    ) {
        guard let activeBattle = session.activeBattle else { return }

        let hero = roster.heroes.first(where: { $0.id == activeBattle.hero.combatant.id })
            ?? roster.activeHero
        let pet = roster.pets.first(where: { $0.id == activeBattle.pet.combatant.id })
            ?? roster.activePet

        session.activeBattle = ActiveBattleConfiguration.make(
            stageID: activeBattle.stageID,
            rngSeed: UInt64.random(in: UInt64.min ... UInt64.max),
            hero: hero,
            pet: pet,
            roster: roster,
            inventory: inventory,
            enemy: activeBattle.enemy,
            enemyEncounterLevel: activeBattle.enemyEncounterLevel,
            stageReward: activeBattle.stageReward,
            rewardItemNames: activeBattle.rewardItemNames,
            catalog: catalog
        )
    }

    private static func rewardItemNames(
        for stageReward: StageReward,
        catalog: PlayerContentCatalog
    ) -> [String] {
        stageReward.itemTemplateIDs.compactMap { templateID in
            catalog.itemTemplate(matching: templateID)?.displayName
        }
    }
}
