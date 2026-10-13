import BattleEngine
import Observation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
@Observable
public final class ContractsPlayMode {
    // Note: contract battles launch cold (no pre-warming like Journey/Spires).
    // Offer IDs rotate on refresh/replace, so cached runs would rarely hit.
    public let playerSave: PlayerSaveStore
    private let battle: any BattleRuntime
    private let battleCoordinator: PlayBattleCoordinator
    var makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer
    private let encounters: EncounterPlayMode

    init(playerSave: PlayerSaveStore, battle: any BattleRuntime, battleCoordinator: PlayBattleCoordinator, encounters: EncounterPlayMode) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleCoordinator = battleCoordinator
        self.encounters = encounters
    }

    @discardableResult
    public func enter() -> StageMapMessage? {
        playerSave.performSaveAction(key: SaveRetryKey.contractsEnter) { [weak self] _ -> StageMapMessage? in
            guard let self else { return nil }
            guard battle.lifecyclePhase != .active else { return PlayBattleCoordinator.activationFailureMessage }
            guard encounters.canBeginTransientEncounter else { return nil }
            _ = playerSave.prepareContracts(makeOffer: makeOffer)
            return nil
        }
    }

    @discardableResult
    public func refresh() -> StageMapMessage? {
        playerSave.performSaveAction(key: SaveRetryKey.contractsRefresh) { [weak self] _ -> StageMapMessage? in
            guard let self else { return nil }
            guard battle.lifecyclePhase != .active else { return PlayBattleCoordinator.activationFailureMessage }
            guard encounters.canBeginTransientEncounter else { return nil }
            guard playerSave.contracts.refreshAvailable else { return nil }
            _ = playerSave.refreshContracts(makeOffer: makeOffer)
            return nil
        }
    }

    public func resolvedEncounter(for offer: ContractOffer) -> ScaledEncounter? {
        PlayBattlePreparation.contractEncounter(
            for: offer,
            partyAverageLevel: playerSave.roster.activePartyAverageLevel,
        )
    }

    @discardableResult
    public func startBattle(offerID: String) -> StageMapMessage? {
        battleCoordinator.startBattle(
            origin: .contract(offerID: offerID),
            encounters: encounters,
            busyMessage: PlayBattleCoordinator.activationFailureMessage,
            resolve: {
                guard let offer = playerSave.contracts.offers.first(where: { $0.id == offerID }) else {
                    return .unavailable(StageMapMessage(
                        title: "Contract Unavailable",
                        message: "Refresh the board and choose another contract.",
                    ))
                }
                guard let encounter = resolvedEncounter(for: offer) else { return .missing }
                let request = combatRequest(for: offer, encounter: encounter)
                return .ready(input: request.input, route: request.route)
            },
        )
    }

    private func combatRequest(
        for offer: ContractOffer,
        encounter: ScaledEncounter,
    ) -> (input: BattleLaunchInput, route: PlayBattleRoute) {
        let loot = BattleLootContext(playerSave: playerSave).contract(for: offer, encounterLevel: encounter.level)
        let input = ModeBattleSpec.launchInput(
            origin: .contract(offerID: offer.id),
            encounter: encounter,
            loot: loot,
            roster: playerSave.roster,
            experienceBonusPercent: RewardOwnership(playerSave.inventory).resolved(offer.rewardModifier)
                .experienceBonusPercent,
        )
        return (input, .contract(offerID: offer.id))
    }
}
