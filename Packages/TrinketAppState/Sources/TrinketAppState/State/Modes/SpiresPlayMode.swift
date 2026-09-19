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
    public let playerSave: PlayerSaveStore
    public let battle: any BattleRuntime
    private let battleLaunch: PlayBattleLaunch
    private let encounters: EncounterPlayMode
    private var preparationTracker = PlayBattlePreparationTracker<SingleBattlePreparationInputs>()

    init(
        playerSave: PlayerSaveStore,
        battle: any BattleRuntime,
        battleLaunch: PlayBattleLaunch,
        encounters: EncounterPlayMode,
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
        self.encounters = encounters
    }

    public func resolvedEncounter(for floor: SpireFloor) -> ScaledEncounter? {
        PlayBattlePreparation.spireEncounter(for: floor)
    }

    private func battleLoot(for floor: SpireFloor, encounterLevel: Int) -> BattleLootResult {
        let loot = BattleLootContext(playerSave: playerSave)
        return SpireCompletion.resolveLoot(
            for: floor,
            encounterLevel: encounterLevel,
            worldSeed: loot.worldSeed,
            ownedTrinketIDs: loot.ownedTrinketIDs,
            ownedUniqueIDs: loot.ownedUniqueIDs,
            astralChanceBonusPercent: loot.astralChanceBonusPercent,
        )
    }

    func battleRoute(floor: SpireFloor) -> PlayBattleRoute {
        PlayBattleRoute.makeModeRoute(
            origin: .spire(spireID: floor.spireID, floor: floor.floor),
            logging: "Failed to persist Spire floor",
            playerSave: playerSave,
        ) { configuration, presentation, award, materialRewards, loot, save in
            SpireCompletion.complete(
                floor: floor,
                hero: configuration.hero.combatant,
                companion: configuration.companion.combatant,
                battleGold: award.award.goldFlow,
                award: award,
                materialRewards: materialRewards,
                rewardItem: presentation?.pendingRewardItem,
                loot: loot,
                enemyEncounterLevel: configuration.enemyEncounterLevel,
                save: &save,
            )
        }
    }

    @discardableResult
    public func startBattle(for floor: SpireFloor) -> StageMapMessage? {
        if let restriction = playerSave.accessRestriction(for: .spire(spireID: floor.spireID, floor: floor.floor)) {
            return restriction
        }
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
            return StageMapMessage(title: "Encounter Missing", message: "This battle is not ready yet.")
        }

        let request = combatRequest(for: floor, encounter: encounter)
        return battleLaunch.startBattle(
            origin: .spire(spireID: floor.spireID, floor: floor.floor),
            encounters: encounters,
            busyMessage: PlayBattleLaunch.activationFailureMessage,
            resolve: { request },
            onActivated: { preparationTracker.invalidate() },
        )
    }

    public func prepareBattle(for floor: SpireFloor) {
        guard playerSave.accessRestriction(for: .spire(spireID: floor.spireID, floor: floor.floor)) == nil else { return }
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

        let origin = PlayBattleOrigin.spire(spireID: floor.spireID, floor: floor.floor)
        battleLaunch.prepareSingleBattle(
            tracker: &preparationTracker,
            origin: origin,
            stageRewardsAlreadyClaimed: false,
            party: PlayBattlePartySnapshot(playerSave: playerSave),
            makeRequest: { combatRequest(for: floor, encounter: encounter) },
        )
    }

    private func combatRequest(
        for floor: SpireFloor,
        encounter: ScaledEncounter,
    ) -> (input: BattleLaunchInput, route: PlayBattleRoute) {
        let loot = battleLoot(for: floor, encounterLevel: encounter.level)
        let input = ModeBattleSpec.launchInput(
            origin: .spire(spireID: floor.spireID, floor: floor.floor),
            encounter: encounter,
            loot: loot,
            roster: playerSave.roster,
        )
        return (input, battleRoute(floor: floor))
    }

    @discardableResult
    func completeFloor(
        _ floor: SpireFloor,
        hero: Combatant,
        companion: Combatant,
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardSettlement? = nil,
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
                battleGold: battleGold,
                award: award,
                materialRewards: materialRewards,
                rewardItem: rewardItem,
                loot: loot,
                enemyEncounterLevel: enemyEncounterLevel,
                save: &save,
            )
        }
    }
}
