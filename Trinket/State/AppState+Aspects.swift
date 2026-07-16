import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    @discardableResult
    func startAspectBattle(for floor: AspectFloor) -> StageMapMessage? {
        guard battle.activeBattle == nil else { return nil }

        guard let aspect = GameContent.aspect(id: floor.aspectID) else {
            return StageMapMessage(title: "Aspect Missing", message: "This Aspect is not ready yet.")
        }

        guard AspectUnlock.isUnlocked(aspect, progress: aspects) else {
            return StageMapMessage(
                title: "Aspect Locked",
                message: AspectUnlock.unlockHint(for: aspect)
            )
        }

        guard aspects.isFloorStartable(floor.floor, aspectID: floor.aspectID.rawValue) else {
            if aspects.isFloorCleared(floor.floor, aspectID: floor.aspectID.rawValue) {
                return StageMapMessage(
                    title: "Floor Cleared",
                    message: "This floor is already complete."
                )
            }
            return StageMapMessage(
                title: "Floor Locked",
                message: "Clear earlier floors first."
            )
        }

        let attunement = AspectAttunement.evaluate(
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            aspect: aspect
        )
        guard attunement.isReady else {
            return StageMapMessage(title: "Not Attuned", message: attunement.message)
        }

        guard let encounter = ActiveBattleConfiguration.resolvedAspectEncounter(for: floor) else {
            return StageMapMessage(title: "Encounter Missing", message: "This floor is not ready yet.")
        }

        activateBattle(
            resumeToken: .aspect(aspectID: floor.aspectID, floor: floor.floor),
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: floor.rewards
        )
        return nil
    }

    func prepareAspectBattle(for floor: AspectFloor) {
        guard battle.activeBattle == nil,
              let aspect = GameContent.aspect(id: floor.aspectID),
              AspectUnlock.isUnlocked(aspect, progress: aspects),
              aspects.isFloorStartable(floor.floor, aspectID: floor.aspectID.rawValue),
              AspectAttunement.evaluate(
                  hero: roster.activeHero,
                  companion: roster.activeCompanion,
                  aspect: aspect
              ).isReady,
              let encounter = ActiveBattleConfiguration.resolvedAspectEncounter(for: floor)
        else { return }

        battle.prepareBattleRun(makeBattleConfiguration(
            resumeToken: .aspect(aspectID: floor.aspectID, floor: floor.floor),
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: floor.rewards
        ))
    }

    @discardableResult
    func completeAspectFloor(
        _ floor: AspectFloor,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil
    ) -> Bool {
        do {
            try playerSave.performBatchMutation { save in
                AspectCompletion.complete(
                    floor: floor,
                    hero: hero,
                    companion: companion,
                    battleEarnedGold: battleEarnedGold,
                    materialRewards: materialRewards,
                    rewardItem: rewardItem,
                    save: &save
                )
            }
            return true
        } catch {
            appStateLogger.error(
                "Failed to persist Aspect floor: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}
