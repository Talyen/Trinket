import BattleEngine
import Foundation
import Observation
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
    public let contracts: ContractsPlayMode
    public let encounters: EncounterPlayMode

    private let battleRunRegistry: PlayBattleRunRegistry
    let battleLaunch: PlayBattleLaunch
    let battleCompletion: PlayBattleCompletion

    public private(set) var pendingDestination: PlayLaunchDestination?
    private var postBattleTalentCombatantIDs: [String] = []

    public var currentPostBattleTalentCombatantID: String? {
        postBattleTalentCombatantIDs.first { playerSave.roster.hasUnlockableTalent(for: $0) }
    }

    private func prunePostBattleTalentCombatantIDs() {
        postBattleTalentCombatantIDs.removeAll { !playerSave.roster.hasUnlockableTalent(for: $0) }
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

        let registry = PlayBattleRunRegistry()
        battleRunRegistry = registry

        let battleLaunch = PlayBattleLaunch(
            playerSave: playerSave,
            shellSession: shellSession,
            battle: battle,
            runRegistry: registry,
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
        )
        self.battleLaunch = battleLaunch
        self.journey = journey
        self.labyrinth = labyrinth
        self.spires = spires
        contracts = ContractsPlayMode(playerSave: playerSave, battle: battle, battleLaunch: battleLaunch, encounters: encounters)
        self.encounters = encounters
        self.battleCompletion = battleCompletion
    }

    public func consumePendingDestination() -> PlayLaunchDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }

    func queueDestination(_ destination: PlayLaunchDestination) {
        pendingDestination = destination
    }

    func queueReturnToBattleOrigin(from origin: PlayBattleOrigin?) {
        pendingDestination = PlayLaunchDestination.returning(from: origin)
    }

    public func endBattleReturningToOrigin() {
        let runKey = battle.activeBattle?.runKey
        let origin = route(for: runKey)?.origin
        if runKey != nil, origin == nil {
            appStateLogger.error("Missing route for active battle dismissal")
        }
        queueReturnToBattleOrigin(from: origin)
        shellSession.selectedTab = .play
        battle.endBattle()
        battleRunRegistry.removeAll()
    }

    @discardableResult
    public func completeActiveBattle(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards: [ResourceAmount]? = nil,
        settlement: BattleRewardSettlement? = nil,
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
            onPersisted: { [weak self] in
                self?.queuePostBattleTalentChoices(
                    for: combatants,
                    progressionsBefore: progressionsBefore,
                )
            },
            queueReturnToOrigin: { [weak self] origin in
                self?.queueReturnToBattleOrigin(from: origin)
            },
        )
        if result.didComplete {
            battleRunRegistry.removeAll()
        }
        return result
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
        prunePostBattleTalentCombatantIDs()
        guard let combatantID = currentPostBattleTalentCombatantID else {
            return .unavailable
        }
        let result = playerSave.unlockTalent(
            nodeID: nodeID,
            treeID: treeID,
            for: combatantID,
        )
        if result == .unlocked {
            if !playerSave.roster.hasUnlockableTalent(for: combatantID) {
                postBattleTalentCombatantIDs.removeAll(where: { $0 == combatantID })
            }
        }
        return result
    }

    public func dismissPostBattleTalentChoice() {
        postBattleTalentCombatantIDs.removeAll(keepingCapacity: true)
    }

    func clearTransientState() {
        battle.endBattle()
        battleRunRegistry.removeAll()
        dismissPostBattleTalentChoice()
        encounters.activeMysteryEncounter = nil
        encounters.activeShopEncounter = nil
        pendingDestination = nil
        shellSession.selectedTab = .play
    }

    func route(for runKey: BattleRunKey?) -> PlayBattleRoute? {
        battleRunRegistry.route(for: runKey)
    }

    public func battlePresentation(for configuration: BattleRunConfiguration) -> BattlePresentationContext? {
        guard let runKey = configuration.runKey else { return .empty }
        guard let registration = battleRunRegistry.registration(for: runKey),
              registration.launch.configuration.id == configuration.id else { return nil }
        return registration.presentation
    }

    func battlePresentation(for runKey: BattleRunKey?) -> BattlePresentationContext? {
        battleRunRegistry.presentation(for: runKey)
    }

    func battleUniversalModifiers(for runKey: BattleRunKey?) -> [AffixModifier] {
        battleRunRegistry.universalModifiers(for: runKey)
    }

    func battleRegistration(for runKey: BattleRunKey?) -> PlayBattleRunRegistration? {
        battleRunRegistry.registration(for: runKey)
    }

    private func queuePostBattleTalentChoices(
        for combatants: [Combatant],
        progressionsBefore: [String: CombatantProgression],
    ) {
        let roster = playerSave.roster
        postBattleTalentCombatantIDs = combatants.compactMap { combatant in
            guard let before = progressionsBefore[combatant.id] else { return nil }
            let after = roster.progression(for: combatant)
            guard after.totalTalentPoints > before.totalTalentPoints,
                  roster.hasUnlockableTalent(for: combatant.id)
            else { return nil }
            return combatant.id
        }
    }
}

@MainActor
final class PlayBattleRunRegistry {
    private var battleRuns: [BattleRunKey: PlayBattleRunRegistration] = [:]

    func register(_ registration: PlayBattleRunRegistration) {
        battleRuns[registration.route.origin.runKey] = registration
    }

    func remove(_ runKey: BattleRunKey) {
        battleRuns.removeValue(forKey: runKey)
    }

    func keep(_ keys: Set<BattleRunKey>) {
        battleRuns = battleRuns.filter { keys.contains($0.key) }
    }

    func registration(for runKey: BattleRunKey?) -> PlayBattleRunRegistration? {
        guard let runKey else { return nil }
        return battleRuns[runKey]
    }

    func route(for runKey: BattleRunKey?) -> PlayBattleRoute? {
        registration(for: runKey)?.route
    }

    func presentation(for runKey: BattleRunKey?) -> BattlePresentationContext? {
        registration(for: runKey)?.presentation
    }

    func universalModifiers(for runKey: BattleRunKey?) -> [AffixModifier] {
        registration(for: runKey)?.universalModifiers ?? []
    }

    func removeAll() {
        battleRuns.removeAll(keepingCapacity: true)
    }
}
