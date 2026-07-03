import Foundation
import Observation
import BattleEngine
import TrinketContent

@MainActor
@Observable
final class BattleSession {
    var activeBattle: ActiveBattleConfiguration?
    var isPaused = false
    var preview: BattleMusicPreview?
    var overlayCombatantDetail: CombatantCollectionDetailSelection?
    var pauseStateBeforeOverlay: Bool?

    func endBattle() {
        activeBattle = nil
        isPaused = false
        preview = nil
        overlayCombatantDetail = nil
        pauseStateBeforeOverlay = nil
    }

    func setMusicPreview(for stage: Stage?) {
        guard activeBattle == nil,
              let stage,
              let enemyID = stage.encounter.battleEnemyID
        else {
            preview = nil
            return
        }

        preview = BattleMusicPreview(stageID: stage.id, enemyID: enemyID)
    }

    @discardableResult
    func startBattle(
        stage: Stage,
        hero: Combatant,
        pet: Combatant,
        roster: PlayerRosterStore,
        inventory: PlayerInventoryStore
    ) -> StageMapMessage? {
        guard let enemyID = stage.encounter.battleEnemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID),
              let chapter = GameContent.chapters.first(where: { $0.id == stage.chapterID })
        else {
            return StageMapMessage(title: "Encounter Missing", message: "This stage is not ready yet.")
        }

        let encounterLevel = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        let enemy = CombatantLevelScaler.scale(enemy: catalogEnemy, level: encounterLevel)

        preview = nil
        let rewardItemNames = stage.rewards.itemTemplateIDs.compactMap { templateID in
            GameContent.itemTemplate(matching: templateID)?.displayName
        }
        activeBattle = ActiveBattleConfiguration.make(
            stageID: stage.id,
            hero: hero,
            pet: pet,
            enemy: enemy,
            enemyEncounterLevel: encounterLevel,
            heroProgression: roster.current.progression(for: hero),
            petProgression: roster.current.progression(for: pet),
            heroEquipmentLoadout: roster.current.equipmentLoadout(for: hero),
            petEquipmentLoadout: roster.current.equipmentLoadout(for: pet),
            inventoryState: inventory.current,
            stageReward: stage.rewards,
            rewardItemNames: rewardItemNames
        )
        return nil
    }

    func restartBattle(using roster: PlayerRosterStore) {
        guard let activeBattle else { return }

        guard
            let hero = roster.heroes.first(where: { $0.id == activeBattle.hero.id }),
            let pet = roster.pets.first(where: { $0.id == activeBattle.pet.id })
        else { return }

        self.activeBattle = ActiveBattleConfiguration.make(
            stageID: activeBattle.stageID,
            hero: hero,
            pet: pet,
            enemy: activeBattle.enemy,
            enemyEncounterLevel: activeBattle.enemyEncounterLevel,
            heroProgression: activeBattle.heroProgression,
            petProgression: activeBattle.petProgression,
            heroEquipmentLoadout: activeBattle.heroEquipmentLoadout,
            petEquipmentLoadout: activeBattle.petEquipmentLoadout,
            inventoryState: activeBattle.inventoryState,
            stageReward: activeBattle.stageReward,
            rewardItemNames: activeBattle.rewardItemNames
        )
    }

    func pauseForOverlay() {
        pauseStateBeforeOverlay = isPaused
        isPaused = true
    }

    func restorePauseAfterOverlay() {
        guard activeBattle != nil else { return }
        isPaused = pauseStateBeforeOverlay ?? false
        pauseStateBeforeOverlay = nil
    }

    func presentCombatantDetail(_ detail: CombatantCardDetail) {
        pauseForOverlay()
        overlayCombatantDetail = CombatantCollectionDetailSelection(battleSnapshot: detail)
    }
}
