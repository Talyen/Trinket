import BattleEngine
import Observation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
@Observable
public final class ContractsPlayMode {
    public let playerSave: PlayerSaveStore
    private let battle: any BattleRuntime
    private let battleLaunch: PlayBattleLaunch
    private let encounters: EncounterPlayMode

    init(playerSave: PlayerSaveStore, battle: any BattleRuntime, battleLaunch: PlayBattleLaunch, encounters: EncounterPlayMode) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
        self.encounters = encounters
    }

    @discardableResult
    public func enter() -> StageMapMessage? {
        guard battle.lifecyclePhase != .active else { return PlayBattleLaunch.activationFailureMessage }
        guard playerSave.persistBatch(logging: "Failed to open Contracts", { save in
            save.contracts.ensureBoard()
        }) else { return saveFailureMessage }
        return nil
    }

    @discardableResult
    public func refresh() -> StageMapMessage? {
        guard battle.lifecyclePhase != .active else { return PlayBattleLaunch.activationFailureMessage }
        guard playerSave.persistBatch(logging: "Failed to refresh Contracts", { save in
            save.contracts.refresh()
        }) else { return saveFailureMessage }
        return nil
    }

    private func resolvedEncounter(for offer: ContractOffer) -> (combatant: Combatant, level: Int)? {
        PlayBattlePreparation.scaledEncounter(
            enemyID: offer.enemyID,
            level: EncounterLevelResolver.contractEnemyLevel(
                difficulty: offer.difficulty,
                partyAverageLevel: playerSave.roster.activePartyAverageLevel,
            ),
        )
    }

    @discardableResult
    public func startBattle(offerID: String) -> StageMapMessage? {
        guard battle.lifecyclePhase != .active else { return PlayBattleLaunch.activationFailureMessage }
        guard encounters.canBeginTransientEncounter else { return nil }
        guard let offer = playerSave.contracts.offers.first(where: { $0.id == offerID }),
              let encounter = resolvedEncounter(for: offer)
        else {
            return StageMapMessage(title: "Contract Unavailable", message: "Refresh the board and choose another contract.")
        }
        battleLaunch.keepPreparedRuns([])
        return battleLaunch.activateRequest(combatRequest(for: offer, encounter: encounter))
    }

    private func combatRequest(
        for offer: ContractOffer,
        encounter: (combatant: Combatant, level: Int),
    ) -> PlayCombatRequest {
        PlayCombatRequest(
            origin: .contract(offerID: offer.id),
            encounter: encounter,
            route: battleRoute(offerID: offer.id),
            loot: ContractsCompletion.resolveLoot(
                for: offer,
                encounterLevel: encounter.level,
                save: playerSave.currentSave,
            ),
        )
    }

    private func battleRoute(offerID: String) -> PlayBattleRoute {
        PlayBattleRoute(origin: .contract(offerID: offerID)) { [weak self] configuration, _, award, _, loot in
            guard let self, let loot, let level = configuration.enemyEncounterLevel else { return false }
            var completed = false
            let persisted = playerSave.persistBatch(logging: "Failed to complete contract") { save in
                completed = ContractsCompletion.complete(
                    offerID: offerID,
                    hero: configuration.hero.combatant,
                    companion: configuration.companion.combatant,
                    encounterLevel: level,
                    loot: loot,
                    battleGold: award.goldFlow,
                    award: award,
                    save: &save,
                )
            }
            return persisted && completed
        }
    }

    private var saveFailureMessage: StageMapMessage {
        StageMapMessage(title: "Couldn't Save Contracts", message: "Your board was not changed. Try again.")
    }
}
