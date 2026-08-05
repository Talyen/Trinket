import Observation
import TrinketBattleContracts
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
    public let shellSession: PlayerShellSessionStore
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
    public private(set) var mapScrollFocus: MapScrollFocus?

    public var mapScrollStageID: String? {
        get { shellSession.mapScrollStageID }
        set { shellSession.mapScrollStageID = newValue }
    }

    public var lastPlayMode: PlayerShellSessionPlayMode {
        get { shellSession.lastPlayMode }
        set { shellSession.lastPlayMode = newValue }
    }

    init(
        playerSave: PlayerSaveStore,
        shellSession: PlayerShellSessionStore,
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

        let scrollSink = PlayMapScrollSink()
        let runCallbacks = LaunchRunCallbacks(
            registerRun: { [registry] reg in registry.register(reg) },
            removeRun: { [registry] key in registry.remove(key) },
            removePreparedRunsExcept: { [registry] key in registry.removeExcept(key) }
        )
        let graph = PlayModeGraph.assemble(
            playerSave: playerSave,
            battle: battle,
            options: options,
            sfxPlayer: sfxPlayer,
            runCallbacks: runCallbacks,
            noteMapScrollFocus: { [scrollSink] targetID in
                scrollSink.noteMapScrollFocus(targetID)
            }
        )
        battleLaunch = graph.battleLaunch
        journey = graph.journey
        labyrinth = graph.labyrinth
        spires = graph.spires
        encounters = graph.encounters
        battleCompletion = graph.battleCompletion
        scrollSink.owner = self
    }

    public func consumePendingDestination() -> PlayLaunchDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
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

    public func noteMapScrollFocus(_ targetID: String) {
        mapScrollStageID = targetID
        let nextRevision = (mapScrollFocus?.revision ?? 0) + 1
        mapScrollFocus = MapScrollFocus(stageID: targetID, revision: nextRevision)
    }

    /// Persists victory rewards and ends the battle only when persistence succeeds.
    @discardableResult
    public func completeActiveBattle(
        _ configuration: BattleRunConfiguration,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]? = nil
    ) -> Bool {
        let persisted = battleCompletion.completeActiveBattle(
            configuration,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards,
            route: route(for: configuration.runKey),
            presentation: battlePresentation(for: configuration.runKey),
            queueReturnToOrigin: { [weak self] origin in
                self?.queueReturnToBattleOrigin(from: origin)
            }
        )
        if persisted, let runKey = configuration.runKey {
            battleRunRegistry.remove(runKey)
        }
        return persisted
    }

    func clearTransientState() {
        battle.endBattle()
        battleRunRegistry.removeAll()
        encounters.activeMysteryEncounter = nil
        encounters.activeShopEncounter = nil
        labyrinth.activeNodeSession = nil
        shellSession.resetToDefaults(selectingTab: .play)
    }

    static func shouldRestoreMapScroll(
        _ targetID: String,
        journey: JourneyProgressState,
        chapters: [Chapter] = GameContent.chapters
    ) -> Bool {
        if targetID.hasPrefix("chapter-gate-") {
            return true
        }
        guard let stage = chapters.flatMap(\.stages).first(where: { $0.id == targetID }) else {
            return false
        }
        return journey.isActive(stage)
    }

    func registerBattleRun(_ registration: PlayBattleRunRegistration) {
        battleRunRegistry.register(registration)
    }

    func removeBattleRun(_ runKey: BattleRunKey) {
        battleRunRegistry.remove(runKey)
    }

    func removeBattleRuns(except runKey: BattleRunKey) {
        battleRunRegistry.removeExcept(runKey)
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

    func removeExcept(_ runKey: BattleRunKey) {
        battleRuns = battleRuns.filter { $0.key == runKey }
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

@MainActor
private final class PlayMapScrollSink {
    weak var owner: PlaySession?

    func noteMapScrollFocus(_ targetID: String) {
        owner?.noteMapScrollFocus(targetID)
    }
}

struct LaunchRunCallbacks {
    let registerRun: @MainActor @Sendable (PlayBattleRunRegistration) -> Void
    let removeRun: @MainActor @Sendable (BattleRunKey) -> Void
    let removePreparedRunsExcept: @MainActor @Sendable (BattleRunKey) -> Void
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
        battle: any BattleRuntime,
        options: OptionsStore,
        sfxPlayer: SFXPlayer,
        runCallbacks: LaunchRunCallbacks,
        noteMapScrollFocus: @escaping @MainActor @Sendable (String) -> Void
    ) -> Assembled {
        let battleLaunch = PlayBattleLaunch(
            playerSave: playerSave,
            battle: battle,
            registerRun: runCallbacks.registerRun,
            removeRun: runCallbacks.removeRun,
            removePreparedRunsExcept: runCallbacks.removePreparedRunsExcept
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
            noteMapScrollFocus: noteMapScrollFocus,
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
