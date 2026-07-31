import Foundation
import Observation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

/// Spire climb flow: prepare/start floor battles and floor completion writes.
@MainActor
@Observable
public final class SpiresPlayMode {
    private let playerSave: PlayerSaveStore
    private let battle: any BattleRuntime
    private let battleLaunch: PlayBattleLaunch

    init(
        playerSave: PlayerSaveStore,
        battle: any BattleRuntime,
        battleLaunch: PlayBattleLaunch
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
    }

    public func resolvedEncounter(for floor: SpireFloor) -> (combatant: Combatant, level: Int)? {
        PlayBattleLaunch.resolvedSpireEncounter(for: floor)
    }

    @discardableResult
    public func startBattle(for floor: SpireFloor) -> StageMapMessage? {
        guard battle.lifecyclePhase != .active else { return nil }

        guard let spire = GameContent.spire(id: floor.spireID) else {
            return StageMapMessage(title: "Spire Missing", message: "This Spire is not ready yet.")
        }

        let spires = playerSave.spires
        let roster = playerSave.roster

        guard spires.isFloorStartable(floor.floor, spireID: floor.spireID.rawValue) else {
            if spires.isFloorCleared(floor.floor, spireID: floor.spireID.rawValue) {
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

        let attunement = SpireAttunement.evaluate(
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            spire: spire
        )
        guard attunement.isReady else {
            return StageMapMessage(title: "Not Attuned", message: attunement.message)
        }

        guard let encounter = resolvedEncounter(for: floor) else {
            return StageMapMessage(title: "Encounter Missing", message: "This floor is not ready yet.")
        }

        battleLaunch.activateCombat(
            origin: .spire(spireID: floor.spireID, floor: floor.floor),
            encounter: encounter
        )
        return nil
    }

    public func prepareBattle(for floor: SpireFloor) {
        let spires = playerSave.spires
        let roster = playerSave.roster
        guard battle.lifecyclePhase != .active,
              let spire = GameContent.spire(id: floor.spireID),
              spires.isFloorStartable(floor.floor, spireID: floor.spireID.rawValue),
              SpireAttunement.evaluate(
                  hero: roster.activeHero,
                  companion: roster.activeCompanion,
                  spire: spire
              ).isReady,
              let encounter = resolvedEncounter(for: floor)
        else { return }

        battleLaunch.prepareCombat(
            origin: .spire(spireID: floor.spireID, floor: floor.floor),
            encounter: encounter
        )
    }

    @discardableResult
    func completeFloor(
        _ floor: SpireFloor,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil
    ) -> Bool {
        do {
            try playerSave.performBatchMutation { save in
                SpireCompletion.complete(
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
                "Failed to persist Spire floor: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}
