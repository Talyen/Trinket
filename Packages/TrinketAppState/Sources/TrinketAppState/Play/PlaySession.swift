import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
@Observable
public final class PlaySession: BattleProgressionDelegate {
    public let playerSave: PlayerSaveStore
    public let shellSession: ShellSession
    public let battle: any BattleRuntime
    public let options: OptionsStore
    public let sfxPlayer: SFXPlayer

    public let journey: JourneyPlayMode
    public let labyrinth: LabyrinthPlayMode
    public let spires: SpiresPlayMode
    public let voyage: VoyagePlayMode
    public let contracts: ContractsPlayMode
    public let encounters: EncounterPlayMode

    let battleCoordinator: PlayBattleCoordinator
    let battleRewardDate: @MainActor () -> Date

    public private(set) var researchCompletionIDs: [String] = []

    public func dismissResearchCompletion(_ ids: [String]) {
        if researchCompletionIDs == ids {
            researchCompletionIDs = []
        }
    }

    public private(set) var pendingDestination: PlayLaunchDestination?
    private var postBattleTalentChoices = PostBattleTalentChoices()

    public var postBattleTalentConfirmationID: UUID? {
        postBattleTalentChoices.confirmationID
    }

    public var currentPostBattleTalentCombatantID: String? {
        postBattleTalentChoices.currentCombatantID(in: playerSave.roster)
    }

    public var isGameplayActive: Bool {
        battle.lifecyclePhase == .active
            || currentPostBattleTalentCombatantID != nil
            || encounters.activeMysteryEncounter != nil
            || encounters.activeShopEncounter != nil
    }

    init(
        playerSave: PlayerSaveStore,
        shellSession: ShellSession,
        battle: any BattleRuntime,
        options: OptionsStore,
        sfxPlayer: SFXPlayer,
        pendingDestination: PlayLaunchDestination?,
        battlePerformanceScenario: BattlePerformanceScenario? = nil,
        battleRewardDate: @escaping @MainActor () -> Date = { Date() },
    ) {
        self.playerSave = playerSave
        self.shellSession = shellSession
        self.battle = battle
        self.options = options
        self.sfxPlayer = sfxPlayer
        self.pendingDestination = pendingDestination
        self.battleRewardDate = battleRewardDate

        let battleCoordinator = PlayBattleCoordinator(
            playerSave: playerSave,
            shellSession: shellSession,
            battle: battle,
            battlePerformanceScenario: battlePerformanceScenario,
        )
        let encounters = EncounterPlayMode(
            playerSave: playerSave,
            battle: battle,
            options: options,
            sfxPlayer: sfxPlayer,
        )
        let journey = JourneyPlayMode(
            playerSave: playerSave,
            battle: battle,
            battleCoordinator: battleCoordinator,
            encounters: encounters,
        )
        let labyrinth = LabyrinthPlayMode(
            playerSave: playerSave,
            battle: battle,
            battleCoordinator: battleCoordinator,
            encounters: encounters,
        )
        let spires = SpiresPlayMode(
            playerSave: playerSave,
            battle: battle,
            battleCoordinator: battleCoordinator,
            encounters: encounters,
        )
        self.battleCoordinator = battleCoordinator
        self.journey = journey
        self.labyrinth = labyrinth
        self.spires = spires
        voyage = VoyagePlayMode(playerSave: playerSave, battle: battle, battleCoordinator: battleCoordinator, encounters: encounters)
        contracts = ContractsPlayMode(playerSave: playerSave, battle: battle, battleCoordinator: battleCoordinator, encounters: encounters)
        self.encounters = encounters
        battle.connectProgression(to: self)
    }

    public func consumePendingDestination() -> PlayLaunchDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }

    public func endBattleReturningToOrigin() {
        let combatants = battle.activeBattle.map { [$0.hero.combatant, $0.companion.combatant] } ?? []
        pendingDestination = nil
        battleCoordinator.endBattleReturningToOrigin {
            queuePostBattleTalentChoices(for: combatants)
        }
    }

    @discardableResult
    public func completeActiveBattle(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards: [ResourceAmount]? = nil,
        settlement: BattleRewardSettlement? = nil,
        defersPresentationExit: Bool = false,
    ) -> BattleCompletionResult {
        let combatants = [configuration.hero.combatant, configuration.companion.combatant]
        return battleCoordinator.completeActiveBattle(
            configuration,
            battleGold: battleGold,
            materialRewards: materialRewards,
            settlement: settlement,
            makeContractOffer: contracts.makeOffer,
            defersPresentationExit: defersPresentationExit,
            onFinished: { [weak self] in
                self?.finishBattleExit(for: combatants)
            },
            onClaimed: { [weak self] in
                guard let self else { return }
                researchCompletionIDs = battleCoordinator.activeRun?.rewardClaim.completedResearchIDs ?? []
                sfxPlayer.play(SFXID.lootCollect, volume: options.effectsVolume)
            },
        )
    }

    public func finishBattleRewardPresentation(configurationID: UUID) {
        battleCoordinator.finishPresentation(configurationID: configurationID)
    }

    public func settleBattleRewards(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards: [ResourceAmount]? = nil,
        at date: Date? = nil,
    ) -> BattleRewardSettlement? {
        guard battle.activeBattle?.id == configuration.id,
              configuration.runKey == nil || route(for: configuration.runKey) != nil else { return nil }
        return battleCoordinator.settleRewards(
            configuration, battleGold: battleGold, materialRewards: materialRewards,
            at: date ?? battleRewardDate(),
        )
    }

    public func choosePostBattleTalent(nodeID: String, treeID: String) -> SaveActionAttempt<RosterEditResult> {
        postBattleTalentChoices.choose(nodeID: nodeID, treeID: treeID, in: playerSave)
    }

    public func dismissPostBattleTalentChoice() {
        postBattleTalentChoices.dismiss()
    }

    public func finishPostBattleTalentConfirmation(id: UUID) {
        postBattleTalentChoices.finishConfirmation(id: id, roster: playerSave.roster)
    }

    func clearTransientState() {
        researchCompletionIDs = []
        battleCoordinator.reset()
        battleCoordinator.endBattle()
        dismissPostBattleTalentChoice()
        encounters.activeMysteryEncounter = nil
        encounters.activeShopEncounter = nil
        pendingDestination = nil
        shellSession.selectedTab = .play
    }

    func route(for runKey: BattleRunKey?) -> PlayBattleRoute? {
        battleCoordinator.registration(for: runKey)?.route
    }

    public func battlePresentation(for configuration: BattleRunConfiguration) -> BattlePresentationContext? {
        guard let registration = battleCoordinator.registration(for: configuration.runKey),
              registration.launch.configuration.id == configuration.id else { return nil }
        return registration.presentation
    }

    func battlePresentation(for runKey: BattleRunKey?) -> BattlePresentationContext? {
        battleCoordinator.registration(for: runKey)?.presentation
    }

    func battleUniversalModifiers(for runKey: BattleRunKey?) -> [AffixModifier] {
        battleCoordinator.registration(for: runKey)?.universalModifiers ?? []
    }

    func battleRegistration(for runKey: BattleRunKey?) -> PlayBattleRunRegistration? {
        battleCoordinator.registration(for: runKey)
    }

    func finishBattleExit(for combatants: [Combatant]) {
        pendingDestination = nil
        queuePostBattleTalentChoices(for: combatants)
    }

    private func queuePostBattleTalentChoices(
        for combatants: [Combatant],
    ) {
        postBattleTalentChoices.queue(
            for: combatants,
            progressionsBefore: battleCoordinator.takeTalentProgressions(),
            roster: playerSave.roster,
        )
    }
}

public extension PlaySession {
    @discardableResult
    func restartActiveBattle() -> StageMapMessage? {
        let combatants = battle.activeBattle.map { [$0.hero.combatant, $0.companion.combatant] } ?? []
        return battleCoordinator.requestRestart {
            finishBattleExit(for: combatants)
        }
    }

    func settleDefeatRewards(_ configuration: BattleRunConfiguration, at date: Date? = nil) -> BattleRewardSettlement? {
        battleCoordinator.settleDefeat(configuration, at: date ?? battleRewardDate())
    }

    func completeDefeat(
        _ configuration: BattleRunConfiguration,
        settlement: BattleRewardSettlement,
        action: BattleDefeatAction,
    ) -> BattleCompletionResult {
        battleCoordinator.completeDefeat(configuration, settlement: settlement, action: action) { [weak self] in
            self?.finishBattleExit(for: [configuration.hero.combatant, configuration.companion.combatant])
        }
    }
}
