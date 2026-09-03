import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
@Observable
public final class SpiresPlayMode {
    private struct PreparationInputs: Equatable {
        let spireID: SpireID
        let floor: Int
        let party: PlayBattlePartySnapshot
    }

    public let playerSave: PlayerSaveStore
    public let battle: any BattleRuntime
    private let battleLaunch: PlayBattleLaunch
    private var preparationTracker = PlayBattlePreparationTracker<PreparationInputs>()

    init(
        playerSave: PlayerSaveStore,
        battle: any BattleRuntime,
        battleLaunch: PlayBattleLaunch,
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
    }

    public func resolvedEncounter(for floor: SpireFloor) -> (combatant: Combatant, level: Int)? {
        Self.resolvedEncounter(
            for: floor,
            partyAverageLevel: playerSave.roster.activePartyAverageLevel,
        )
    }

    static func resolvedEncounter(
        for floor: SpireFloor,
        partyAverageLevel: Int,
    ) -> (combatant: Combatant, level: Int)? {
        PlayBattlePreparation.scaledEncounter(
            enemyID: floor.enemyID,
            authoredLevel: EncounterLevelResolver.spireEnemyLevel(for: floor),
            partyAverageLevel: partyAverageLevel,
        )
    }

    private func battleLoot(for floor: SpireFloor, encounterLevel: Int) -> BattleLootResult? {
        SpireCompletion.resolveLoot(
            for: floor,
            encounterLevel: encounterLevel,
            worldSeed: playerSave.worldSeed,
            ownedTrinketIDs: playerSave.inventory.ownedTrinketIDs,
            ownedUniqueIDs: playerSave.inventory.ownedUniqueIDs,
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent,
        )
    }

    func battleRoute(spireID: SpireID, floor: Int) -> PlayBattleRoute {
        let origin = PlayBattleOrigin.spire(spireID: spireID, floor: floor)
        return PlayBattleRoute(origin: origin) { [weak self] configuration, presentation, battleEarnedGold, materialRewards, loot in
            guard let self,
                  let resolvedFloor = GameContent.spireFloor(spireID: spireID, floor: floor)
            else { return false }
            return completeFloor(
                resolvedFloor,
                hero: configuration.hero.combatant,
                companion: configuration.companion.combatant,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: presentation?.pendingRewardItem,
                loot: loot,
                enemyEncounterLevel: configuration.enemyEncounterLevel,
            )
        }
    }

    @discardableResult
    public func startBattle(for floor: SpireFloor) -> StageMapMessage? {
        guard let spire = GameContent.spire(id: floor.spireID) else {
            return StageMapMessage(title: "Spire Missing", message: "This Spire is not ready yet.")
        }

        let spires = playerSave.spires
        let roster = playerSave.roster

        guard spires.isFloorStartable(
            floor.floor,
            spireID: floor.spireID.rawValue,
            floorCount: spire.floorCount,
        ) else {
            if spires.isFloorCleared(floor.floor, spireID: floor.spireID.rawValue) {
                return StageMapMessage(
                    title: "Floor Cleared",
                    message: "This floor is already complete.",
                )
            }
            return StageMapMessage(
                title: "Floor Locked",
                message: "Clear earlier floors first.",
            )
        }

        let attunement = SpireAttunement.evaluate(
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            spire: spire,
        )
        guard attunement.isReady else {
            return StageMapMessage(title: "Not Attuned", message: attunement.message)
        }

        guard let encounter = resolvedEncounter(for: floor) else {
            return StageMapMessage(title: "Encounter Missing", message: "This floor is not ready yet.")
        }

        let request = combatRequest(for: floor, encounter: encounter)
        guard battle.lifecyclePhase != .active else { return PlayBattleLaunch.activationFailureMessage }
        let activated = battleLaunch.activateCombat(request)
        if activated {
            preparationTracker.invalidate()
            return nil
        }
        return PlayBattleLaunch.activationFailureMessage
    }

    public func prepareBattle(for floor: SpireFloor) {
        let spires = playerSave.spires
        let roster = playerSave.roster
        guard battle.lifecyclePhase != .active,
              let spire = GameContent.spire(id: floor.spireID),
              spires.isFloorStartable(
                  floor.floor,
                  spireID: floor.spireID.rawValue,
                  floorCount: spire.floorCount,
              ),
              SpireAttunement.evaluate(
                  hero: roster.activeHero,
                  companion: roster.activeCompanion,
                  spire: spire,
              ).isReady,
              let encounter = resolvedEncounter(for: floor)
        else { return }

        let request = combatRequest(for: floor, encounter: encounter)
        let inputs = preparationInputs(for: floor)
        guard preparationTracker.shouldPrepare(
            for: inputs,
            lifecycle: battle.lifecyclePhase,
            hasPreparedRun: battle.hasPreparedRun(request.origin.runKey),
        ) else { return }
        let prepared = battleLaunch.prepareCombat(request)
        if prepared {
            preparationTracker.notePrepared(inputs)
        }
    }

    private func preparationInputs(for floor: SpireFloor) -> PreparationInputs {
        PreparationInputs(
            spireID: floor.spireID,
            floor: floor.floor,
            party: PlayBattlePartySnapshot(playerSave: playerSave),
        )
    }

    private func combatRequest(
        for floor: SpireFloor,
        encounter: (combatant: Combatant, level: Int),
    ) -> PlayCombatRequest {
        PlayCombatRequest(
            origin: .spire(spireID: floor.spireID, floor: floor.floor),
            encounter: encounter,
            route: battleRoute(spireID: floor.spireID, floor: floor.floor),
            loot: battleLoot(for: floor, encounterLevel: encounter.level),
            stageRewardsAlreadyClaimed: false,
            universalModifiers: [],
            labyrinthModifiers: [],
        )
    }

    @discardableResult
    func completeFloor(
        _ floor: SpireFloor,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootResult? = nil,
        enemyEncounterLevel: Int? = nil,
    ) -> Bool {
        playerSave.persistBatch(logging: "Failed to persist Spire floor") { save in
            SpireCompletion.complete(
                floor: floor,
                hero: hero,
                companion: companion,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: rewardItem,
                loot: loot,
                enemyEncounterLevel: enemyEncounterLevel,
                save: &save,
            )
        }
    }
}
