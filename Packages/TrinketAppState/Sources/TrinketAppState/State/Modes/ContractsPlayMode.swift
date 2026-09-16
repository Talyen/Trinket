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
        }) else {
            playerSave.retrySaveAction(key: SaveRetryKey.contractsEnter) { [weak self] in _ = self?.enter() }
            return nil
        }
        return nil
    }

    @discardableResult
    public func refresh() -> StageMapMessage? {
        guard battle.lifecyclePhase != .active else { return PlayBattleLaunch.activationFailureMessage }
        guard playerSave.persistBatch(logging: "Failed to refresh Contracts", { save in
            save.contracts.refresh()
        }) else {
            playerSave.retrySaveAction(key: SaveRetryKey.contractsRefresh) { [weak self] in _ = self?.refresh() }
            return nil
        }
        return nil
    }

    public func resolvedEncounter(for offer: ContractOffer) -> ScaledEncounter? {
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
        guard let offer = playerSave.contracts.offers.first(where: { $0.id == offerID }) else {
            return StageMapMessage(title: "Contract Unavailable", message: "Refresh the board and choose another contract.")
        }
        return battleLaunch.startBattle(
            origin: .contract(offerID: offer.id),
            encounters: encounters,
            busyMessage: PlayBattleLaunch.activationFailureMessage,
            resolve: {
                guard let encounter = resolvedEncounter(for: offer) else { return nil }
                return combatRequest(for: offer, encounter: encounter)
            },
        )
    }

    private func combatRequest(
        for offer: ContractOffer,
        encounter: ScaledEncounter,
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
            guard let self, let loot, let level = configuration.enemyEncounterLevel else { return .unavailable }
            let result = playerSave.persistTransaction(logging: "Failed to complete contract") { save -> Result<Void, CompletionFailure> in
                let completed = ContractsCompletion.complete(
                    offerID: offerID,
                    hero: configuration.hero.combatant,
                    companion: configuration.companion.combatant,
                    encounterLevel: level,
                    loot: loot,
                    battleGold: award.award.goldFlow,
                    award: award,
                    save: &save,
                )
                return completed ? .success(()) : .failure(.unavailable)
            }
            switch result {
            case .committed: return .completed
            case .rejected: return .unavailable
            case .persistFailed: return .persistenceFailed
            }
        }
    }

    private enum CompletionFailure: Error {
        case unavailable
    }
}
