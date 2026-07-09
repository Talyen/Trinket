import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    @discardableResult
    func startAspectBattle(for floor: AspectFloor) -> StageMapMessage? {
        guard battle.activeBattle == nil else { return nil }

        guard ModesUnlock.isUnlocked(journey: journey.current) else {
            return StageMapMessage(title: "Modes Locked", message: ModesUnlock.unlockHint)
        }

        guard let aspect = GameContent.aspect(id: floor.aspectID) else {
            return StageMapMessage(title: "Aspect Missing", message: "This Aspect is not ready yet.")
        }

        guard AspectUnlock.isUnlocked(aspect, progress: aspects.current) else {
            return StageMapMessage(
                title: "Aspect Locked",
                message: AspectUnlock.unlockHint(for: aspect)
            )
        }

        guard aspects.current.isFloorUnlocked(
            floor.floor,
            aspectID: floor.aspectID.rawValue,
            floorCount: aspect.floorCount
        ) else {
            return StageMapMessage(
                title: "Floor Locked",
                message: "Clear earlier floors first."
            )
        }

        let attunement = AspectAttunement.evaluate(
            hero: roster.activeHero,
            pet: roster.activePet,
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
            pet: roster.activePet,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: floor.rewards
        )
        return nil
    }

    func completeAspectFloor(
        _ floor: AspectFloor,
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil
    ) {
        do {
            try playerSave.performBatchMutation { save in
                AspectCompletion.complete(
                    floor: floor,
                    hero: hero,
                    pet: pet,
                    battleEarnedGold: battleEarnedGold,
                    materialRewards: materialRewards,
                    rewardItem: rewardItem,
                    save: &save
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to persist Aspect floor: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
