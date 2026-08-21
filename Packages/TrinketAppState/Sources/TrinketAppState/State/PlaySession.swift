import Observation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

/// Play-tab shell and mode registry: navigation, shared battle launch, and victory routing.
///
/// Mode-specific flow lives on `journey`, `labyrinth`, `spires`, and `encounters`.
/// Shared battle lifecycle glue lives on `PlayBattleLaunch` / `PlayBattleCompletion`.
/// Save slices are read from `playerSave` — not forwarded through this type.
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
    public let encounters: EncounterPlayMode

    private let battleRunRegistry: PlayBattleRunRegistry
    let battleLaunch: PlayBattleLaunch
    let battleCompletion: PlayBattleCompletion

    public private(set) var pendingDestination: PlayLaunchDestination?
    private var postBattleTalentCombatantIDs: [String] = []

    public var currentPostBattleTalentCombatantID: String? {
        postBattleTalentCombatantIDs.first
    }

    init(
        playerSave: PlayerSaveStore,
        shellSession: ShellSession,
        battle: any BattleRuntime,
        options: OptionsStore,
        sfxPlayer: SFXPlayer,
        pendingDestination: PlayLaunchDestination?
    ) {
        self.playerSave = playerSave
        self.shellSession = shellSession
        self.battle = battle
        self.options = options
        self.sfxPlayer = sfxPlayer
        self.pendingDestination = pendingDestination

        let registry = PlayBattleRunRegistry()
        battleRunRegistry = registry

        let runCallbacks = LaunchRunCallbacks(
            registerRun: { [registry] reg in registry.register(reg) },
            removeRun: { [registry] key in registry.remove(key) },
            keepPreparedRuns: { [registry] keys in registry.keep(keys) }
        )
        let graph = PlayModeGraph.assemble(
            playerSave: playerSave,
            shellSession: shellSession,
            battle: battle,
            options: options,
            sfxPlayer: sfxPlayer,
            runCallbacks: runCallbacks
        )
        battleLaunch = graph.battleLaunch
        journey = graph.journey
        labyrinth = graph.labyrinth
        spires = graph.spires
        encounters = graph.encounters
        battleCompletion = graph.battleCompletion
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
        if let runKey {
            battleRunRegistry.remove(runKey)
        }
    }

    /// Persists victory rewards and ends the battle only when persistence succeeds.
    @discardableResult
    public func completeActiveBattle(
        _ configuration: BattleRunConfiguration,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]? = nil
    ) -> Bool {
        let combatants = [configuration.hero.combatant, configuration.companion.combatant]
        let progressionsBefore = Dictionary(
            uniqueKeysWithValues: combatants.map { combatant in
                (combatant.id, playerSave.roster.progression(for: combatant))
            }
        )
        let persisted = battleCompletion.completeActiveBattle(
            configuration,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards,
            route: route(for: configuration.runKey),
            presentation: battlePresentation(for: configuration.runKey),
            onPersisted: { [weak self] in
                self?.queuePostBattleTalentChoices(
                    for: combatants,
                    progressionsBefore: progressionsBefore
                )
            },
            queueReturnToOrigin: { [weak self] origin in
                self?.queueReturnToBattleOrigin(from: origin)
            }
        )
        if persisted, let runKey = configuration.runKey {
            battleRunRegistry.remove(runKey)
        }
        return persisted
    }

    public func choosePostBattleTalent(nodeID: String, treeID: String) -> TalentUnlockResult {
        guard let combatantID = postBattleTalentCombatantIDs.first else {
            return .unavailable
        }
        let result = playerSave.unlockTalent(
            nodeID: nodeID,
            treeID: treeID,
            for: combatantID
        )
        if result == .unlocked {
            postBattleTalentCombatantIDs.removeFirst()
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
        labyrinth.activeNodeSession = nil
        shellSession.selectedTab = .play
    }

    func route(for runKey: BattleRunKey?) -> PlayBattleRoute? {
        battleRunRegistry.route(for: runKey)
    }

    public func battlePresentation(for runKey: BattleRunKey?) -> BattlePresentationContext? {
        battleRunRegistry.presentation(for: runKey)
    }

    func battleUniversalModifiers(for runKey: BattleRunKey?) -> [AffixModifier] {
        battleRunRegistry.universalModifiers(for: runKey)
    }

    private func queuePostBattleTalentChoices(
        for combatants: [Combatant],
        progressionsBefore: [String: CombatantProgression]
    ) {
        postBattleTalentCombatantIDs = combatants.compactMap { combatant in
            guard let before = progressionsBefore[combatant.id] else { return nil }
            let roster = playerSave.roster
            let after = roster.progression(for: combatant)
            guard after.totalTalentPoints > before.totalTalentPoints,
                  roster.availableTalentPoints(for: combatant.id) > 0
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

    func route(for runKey: BattleRunKey?) -> PlayBattleRoute? {
        guard let runKey else { return nil }
        return battleRuns[runKey]?.route
    }

    func presentation(for runKey: BattleRunKey?) -> BattlePresentationContext? {
        guard let runKey else { return nil }
        return battleRuns[runKey]?.presentation
    }

    func universalModifiers(for runKey: BattleRunKey?) -> [AffixModifier] {
        guard let runKey else { return [] }
        return battleRuns[runKey]?.universalModifiers ?? []
    }

    func removeAll() {
        battleRuns.removeAll(keepingCapacity: true)
    }
}

struct LaunchRunCallbacks {
    let registerRun: @MainActor @Sendable (PlayBattleRunRegistration) -> Void
    let removeRun: @MainActor @Sendable (BattleRunKey) -> Void
    let keepPreparedRuns: @MainActor @Sendable (Set<BattleRunKey>) -> Void
}

/// Assembles a fully wired Play mode graph in one place — no deferred bind steps.
@MainActor
enum PlayModeGraph {
    struct Assembled {
        let battleLaunch: PlayBattleLaunch
        let journey: JourneyPlayMode
        let labyrinth: LabyrinthPlayMode
        let spires: SpiresPlayMode
        let encounters: EncounterPlayMode
        let battleCompletion: PlayBattleCompletion
    }

    static func assemble(
        playerSave: PlayerSaveStore,
        shellSession: ShellSession,
        battle: any BattleRuntime,
        options: OptionsStore,
        sfxPlayer: SFXPlayer,
        runCallbacks: LaunchRunCallbacks
    ) -> Assembled {
        let battleLaunch = PlayBattleLaunch(
            playerSave: playerSave,
            shellSession: shellSession,
            battle: battle,
            registerRun: runCallbacks.registerRun,
            removeRun: runCallbacks.removeRun,
            keepPreparedRunRegistrations: runCallbacks.keepPreparedRuns
        )
        let encounters = EncounterPlayMode(
            playerSave: playerSave,
            battle: battle,
            options: options,
            sfxPlayer: sfxPlayer
        )
        let journey = JourneyPlayMode(
            playerSave: playerSave,
            battle: battle,
            battleLaunch: battleLaunch,
            encounters: encounters
        )
        let labyrinth = LabyrinthPlayMode(
            playerSave: playerSave,
            battle: battle,
            battleLaunch: battleLaunch,
            encounters: encounters
        )
        let spires = SpiresPlayMode(
            playerSave: playerSave,
            battle: battle,
            battleLaunch: battleLaunch
        )
        let battleCompletion = PlayBattleCompletion(
            playerSave: playerSave,
            battle: battle
        )

        return Assembled(
            battleLaunch: battleLaunch,
            journey: journey,
            labyrinth: labyrinth,
            spires: spires,
            encounters: encounters,
            battleCompletion: battleCompletion
        )
    }
}
