import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketPersistence

@MainActor
@Observable
final class BattleSession {
    var activeBattle: ActiveBattleConfiguration?
    var isPaused = false
    var preview: BattleMusicPreview?
    var overlayCombatantDetail: CombatantCollectionDetailSelection?
    private var overlayPauseDepth = 0
    private var pauseStateBeforeFirstOverlay: Bool?
    var onBattleStateChange: ((String?) -> Void)?
    var onBattleEnded: (() -> Void)?

    func endBattle() {
        activeBattle = nil
        isPaused = false
        preview = nil
        overlayCombatantDetail = nil
        overlayPauseDepth = 0
        pauseStateBeforeFirstOverlay = nil
        onBattleStateChange?(nil)
        onBattleEnded?()
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
        guard activeBattle == nil else { return nil }

        guard let enemyID = stage.encounter.battleEnemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID),
              let chapter = GameContent.chapters.first(where: { $0.id == stage.chapterID })
        else {
            return StageMapMessage(title: "Encounter Missing", message: "This stage is not ready yet.")
        }

        let encounterLevel = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        let enemy = CombatantLevelScaler.scale(enemy: catalogEnemy, level: encounterLevel)

        preview = nil
        activeBattle = ActiveBattleConfiguration.make(
            stageID: stage.id,
            rngSeed: BattleRNGSeed.fresh(),
            hero: hero,
            pet: pet,
            enemy: enemy,
            enemyEncounterLevel: encounterLevel,
            stageReward: stage.rewards,
            rewardItemNames: stage.rewards.itemTemplateIDs.compactMap { templateID in
                GameContent.itemTemplate(matching: templateID)?.displayName
            },
            roster: roster,
            inventory: inventory
        )
        onBattleStateChange?(stage.id)
        return nil
    }

    func restartBattle(using roster: PlayerRosterStore, inventory: PlayerInventoryStore) {
        guard let activeBattle else { return }

        let hero = roster.heroes.first(where: { $0.id == activeBattle.hero.id })
            ?? roster.activeHero
        let pet = roster.pets.first(where: { $0.id == activeBattle.pet.id })
            ?? roster.activePet

        self.activeBattle = ActiveBattleConfiguration.make(
            stageID: activeBattle.stageID,
            rngSeed: BattleRNGSeed.fresh(),
            hero: hero,
            pet: pet,
            enemy: activeBattle.enemy,
            enemyEncounterLevel: activeBattle.enemyEncounterLevel,
            stageReward: activeBattle.stageReward,
            rewardItemNames: activeBattle.rewardItemNames,
            roster: roster,
            inventory: inventory
        )
    }

    func pauseForOverlay() {
        if overlayPauseDepth == 0 {
            pauseStateBeforeFirstOverlay = isPaused
        }
        overlayPauseDepth += 1
        isPaused = true
    }

    func restorePauseAfterOverlay() {
        guard overlayPauseDepth > 0 else { return }
        overlayPauseDepth -= 1
        guard activeBattle != nil else {
            overlayPauseDepth = 0
            pauseStateBeforeFirstOverlay = nil
            return
        }
        if overlayPauseDepth == 0 {
            isPaused = pauseStateBeforeFirstOverlay ?? false
            pauseStateBeforeFirstOverlay = nil
        }
    }

    func presentCombatantDetail(_ detail: CombatantCardDetail) {
        if activeBattle != nil {
            pauseForOverlay()
        }
        overlayCombatantDetail = CombatantCollectionDetailSelection(battleSnapshot: detail)
    }
}
