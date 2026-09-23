import BattleEngine
import Foundation
import Observation
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
@Observable
public final class PlaySession {
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

    private let battleRuns: PlayBattleRuns
    let battleLaunch: PlayBattleLaunch
    let battleCompletion: PlayBattleCompletion

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
    ) {
        self.playerSave = playerSave
        self.shellSession = shellSession
        self.battle = battle
        self.options = options
        self.sfxPlayer = sfxPlayer
        self.pendingDestination = pendingDestination

        let runs = PlayBattleRuns(battle: battle)
        battleRuns = runs

        let battleLaunch = PlayBattleLaunch(
            playerSave: playerSave,
            shellSession: shellSession,
            battle: battle,
            runs: runs,
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
            battleLaunch: battleLaunch,
            encounters: encounters,
        )
        let labyrinth = LabyrinthPlayMode(
            playerSave: playerSave,
            battle: battle,
            battleLaunch: battleLaunch,
            encounters: encounters,
        )
        let spires = SpiresPlayMode(
            playerSave: playerSave,
            battle: battle,
            battleLaunch: battleLaunch,
            encounters: encounters,
        )
        let battleCompletion = PlayBattleCompletion(
            playerSave: playerSave,
            battle: battle,
            runs: runs,
        )
        self.battleLaunch = battleLaunch
        self.journey = journey
        self.labyrinth = labyrinth
        self.spires = spires
        voyage = VoyagePlayMode(playerSave: playerSave, battle: battle, battleLaunch: battleLaunch, encounters: encounters)
        contracts = ContractsPlayMode(playerSave: playerSave, battle: battle, battleLaunch: battleLaunch, encounters: encounters)
        self.encounters = encounters
        self.battleCompletion = battleCompletion
    }

    public func consumePendingDestination() -> PlayLaunchDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }

    private func restoreBattleOrigin(from origin: PlayBattleOrigin?) {
        pendingDestination = nil
        if let path = PlayLaunchDestination.returnPath(from: origin) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                shellSession.playPath = path
            }
        }
    }

    public func endBattleReturningToOrigin() {
        let configuration = battle.activeBattle
        let runKey = configuration?.runKey
        let origin = route(for: runKey)?.origin
        if runKey != nil, origin == nil {
            appStateLogger.error("Missing route for active battle dismissal")
        }
        restoreBattleOrigin(from: origin)
        shellSession.selectedTab = .play
        battleRuns.endBattle()
        if let configuration, !battleCompletion.deferredDefeatTalentProgressions.isEmpty {
            queuePostBattleTalentChoices(
                for: [configuration.hero.combatant, configuration.companion.combatant],
                progressionsBefore: [:],
            )
        }
        // Clear any deferred victory exit and stale defeat claim. Talent
        // choices above already consumed the deferred progressions, so this
        // only drops the pending exit and claim slot.
        battleCompletion.cancelPendingExit()
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
        let progressionsBefore = Dictionary(
            uniqueKeysWithValues: combatants.map { combatant in
                (combatant.id, playerSave.roster.progression(for: combatant))
            },
        )
        let result = battleCompletion.completeActiveBattle(
            configuration,
            battleGold: battleGold,
            materialRewards: materialRewards,
            settlement: settlement,
            route: route(for: configuration.runKey),
            presentation: battlePresentation(for: configuration.runKey),
            defersPresentationExit: defersPresentationExit,
            onFinished: { [weak self] in
                self?.queuePostBattleTalentChoices(
                    for: combatants,
                    progressionsBefore: progressionsBefore,
                )
            },
            restoreOrigin: { [weak self] origin in
                self?.restoreBattleOrigin(from: origin)
            },
        )
        if result == .persistenceFailed {
            // Retry the same settlement so a stale award refreshes instead of
            // paying out unchecked. The retry exits immediately rather than
            // re-deferring: recovery must converge without another tap.
            playerSave.retrySaveAction(key: SaveRetryKey.victory(configuration.id)) { [weak self] in
                guard let self, battle.activeBattle?.id == configuration.id else { return }
                _ = completeActiveBattle(
                    configuration, battleGold: battleGold, materialRewards: materialRewards,
                    settlement: settlement, defersPresentationExit: false,
                )
            }
        }
        return result
    }

    public func finishBattleRewardPresentation(configurationID: UUID) {
        battleCompletion.finishPresentation(configurationID: configurationID)
    }

    public func settleBattleRewards(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards: [ResourceAmount]? = nil,
        at date: Date = Date(),
    ) -> BattleRewardSettlement? {
        guard battle.activeBattle?.id == configuration.id,
              configuration.runKey == nil || route(for: configuration.runKey) != nil else { return nil }
        return battleCompletion.settleRewards(
            configuration, battleGold: battleGold, materialRewards: materialRewards,
            presentation: battlePresentation(for: configuration.runKey), at: date,
        )
    }

    public func choosePostBattleTalent(nodeID: String, treeID: String) -> TalentUnlockResult {
        postBattleTalentChoices.choose(nodeID: nodeID, treeID: treeID, in: playerSave)
    }

    public func dismissPostBattleTalentChoice() {
        postBattleTalentChoices.dismiss()
    }

    public func finishPostBattleTalentConfirmation(id: UUID) {
        postBattleTalentChoices.finishConfirmation(id: id, roster: playerSave.roster)
    }

    func clearTransientState() {
        battleCompletion.cancelPendingExit()
        battleRuns.endBattle()
        dismissPostBattleTalentChoice()
        encounters.activeMysteryEncounter = nil
        encounters.activeShopEncounter = nil
        pendingDestination = nil
        shellSession.selectedTab = .play
    }

    func route(for runKey: BattleRunKey?) -> PlayBattleRoute? {
        battleRuns.registration(for: runKey)?.route
    }

    public func battlePresentation(for configuration: BattleRunConfiguration) -> BattlePresentationContext? {
        guard let runKey = configuration.runKey else { return .empty }
        guard let registration = battleRuns.registration(for: runKey),
              registration.launch.configuration.id == configuration.id else { return nil }
        return registration.presentation
    }

    func battlePresentation(for runKey: BattleRunKey?) -> BattlePresentationContext? {
        battleRuns.registration(for: runKey)?.presentation
    }

    func battleUniversalModifiers(for runKey: BattleRunKey?) -> [AffixModifier] {
        battleRuns.registration(for: runKey)?.universalModifiers ?? []
    }

    func battleRegistration(for runKey: BattleRunKey?) -> PlayBattleRunRegistration? {
        battleRuns.registration(for: runKey)
    }

    private func queuePostBattleTalentChoices(
        for combatants: [Combatant],
        progressionsBefore: [String: CombatantProgression],
    ) {
        postBattleTalentChoices.queue(
            for: combatants,
            progressionsBefore: progressionsBefore,
            deferredProgressions: battleCompletion.deferredDefeatTalentProgressions,
            roster: playerSave.roster,
        )
        battleCompletion.deferredDefeatTalentProgressions.removeAll()
    }
}
