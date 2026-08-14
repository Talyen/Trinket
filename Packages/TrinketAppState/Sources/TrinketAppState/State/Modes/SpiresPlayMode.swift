import BattleEngine
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
    public let playerSave: PlayerSaveStore
    public let battle: any BattleRuntime
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
        Self.resolvedEncounter(for: floor)
    }

    static func resolvedEncounter(
        for floor: SpireFloor
    ) -> (combatant: Combatant, level: Int)? {
        guard let catalogEnemy = GameContent.enemy(matching: floor.enemyID) else { return nil }
        let level = SpireCompletion.enemyLevel(for: floor)
        return (CombatantLevelScaler.scale(enemy: catalogEnemy, level: level), level)
    }

    private func battleLoot(for floor: SpireFloor) -> BattleLootPackage? {
        Self.resolveBattleLoot(
            for: floor,
            ownedTrinketIDs: playerSave.inventory.ownedTrinketIDs,
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent
        )
    }

    static func resolveBattleLoot(
        for floor: SpireFloor,
        ownedTrinketIDs: Set<String> = [],
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage? {
        SpireCompletion.resolveLoot(
            for: floor,
            ownedTrinketIDs: ownedTrinketIDs,
            astralChanceBonusPercent: astralChanceBonusPercent
        )
    }

    func battleRoute(spireID: SpireID, floor: Int) -> PlayBattleRoute {
        let origin = PlayBattleOrigin.spire(spireID: spireID, floor: floor)
        return PlayBattleRoute(origin: origin) { [weak self] configuration, presentation, battleEarnedGold, materialRewards in
            guard let self,
                  let resolvedFloor = GameContent.spireFloor(spireID: spireID, floor: floor)
            else { return false }
            return completeFloor(
                resolvedFloor,
                hero: configuration.hero.combatant,
                companion: configuration.companion.combatant,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: presentation?.pendingRewardItem
            )
        }
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

        let origin = PlayBattleOrigin.spire(spireID: floor.spireID, floor: floor.floor)
        let activated = battleLaunch.activateCombat(
            origin: origin,
            encounter: encounter,
            route: battleRoute(spireID: floor.spireID, floor: floor.floor),
            loot: battleLoot(for: floor)
        )
        return activated ? nil : PlayBattleLaunch.activationFailureMessage
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

        let origin = PlayBattleOrigin.spire(spireID: floor.spireID, floor: floor.floor)
        battleLaunch.prepareCombat(
            origin: origin,
            encounter: encounter,
            route: battleRoute(spireID: floor.spireID, floor: floor.floor),
            loot: battleLoot(for: floor)
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
        playerSave.persistBatch(logging: "Failed to persist Spire floor") { save in
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
    }
}
