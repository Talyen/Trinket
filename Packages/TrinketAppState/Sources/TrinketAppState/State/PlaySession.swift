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

    private let mapScrollFocusSink: MapScrollFocusSink
    private let battleRouteSink: BattleRouteSink
    private var battleRuns: [BattleRunKey: PlayBattleRunRecord] = [:]
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

        let focusSink = MapScrollFocusSink()
        mapScrollFocusSink = focusSink
        let routeSink = BattleRouteSink()
        battleRouteSink = routeSink
        let graph = PlayModeGraph.assemble(
            playerSave: playerSave,
            battle: battle,
            options: options,
            sfxPlayer: sfxPlayer,
            noteMapScrollFocus: { targetID in focusSink.note(targetID) },
            battleRunSink: routeSink
        )
        battleLaunch = graph.battleLaunch
        journey = graph.journey
        labyrinth = graph.labyrinth
        spires = graph.spires
        encounters = graph.encounters
        battleCompletion = graph.battleCompletion
        focusSink.owner = self
        routeSink.owner = self
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
            battleRuns.removeValue(forKey: runKey)
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
            battleRuns.removeValue(forKey: runKey)
        }
        return persisted
    }

    func clearTransientState() {
        battle.endBattle()
        battleRuns.removeAll(keepingCapacity: true)
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
        battleRuns[registration.route.origin.runKey] = PlayBattleRunRecord(
            route: registration.route,
            presentation: registration.presentation,
            universalModifiers: registration.universalModifiers
        )
    }

    func removeBattleRun(_ runKey: BattleRunKey) {
        battleRuns.removeValue(forKey: runKey)
    }

    func removeBattleRuns(except runKey: BattleRunKey) {
        battleRuns = battleRuns.filter { $0.key == runKey }
    }

    func route(for runKey: BattleRunKey?) -> PlayBattleRoute? {
        guard let runKey else { return nil }
        return battleRuns[runKey]?.route
    }

    public func battlePresentation(for runKey: BattleRunKey?) -> BattlePresentationContext? {
        guard let runKey else { return nil }
        return battleRuns[runKey]?.presentation
    }

    func battleUniversalModifiers(for runKey: BattleRunKey?) -> [AffixModifier] {
        guard let runKey else { return [] }
        return battleRuns[runKey]?.universalModifiers ?? []
    }
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
        noteMapScrollFocus: @escaping (String) -> Void,
        battleRunSink: BattleRouteSink
    ) -> Assembled {
        let battleLaunch = PlayBattleLaunch(
            playerSave: playerSave,
            battle: battle,
            registerRun: { registration in
                battleRunSink.register(registration)
            },
            removeRun: { runKey in
                battleRunSink.remove(runKey: runKey)
            },
            removePreparedRunsExcept: { runKey in
                battleRunSink.removePreparedRunsExcept(runKey: runKey)
            }
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

@MainActor
private final class MapScrollFocusSink {
    weak var owner: PlaySession?

    func note(_ targetID: String) {
        owner?.noteMapScrollFocus(targetID)
    }
}

@MainActor
final class BattleRouteSink {
    weak var owner: PlaySession?

    func register(_ registration: PlayBattleRunRegistration) {
        owner?.registerBattleRun(registration)
    }

    func remove(runKey: BattleRunKey) {
        owner?.removeBattleRun(runKey)
    }

    func removePreparedRunsExcept(runKey: BattleRunKey) {
        owner?.removeBattleRuns(except: runKey)
    }
}

private struct PlayBattleRunRecord {
    let route: PlayBattleRoute
    let presentation: BattlePresentationContext
    let universalModifiers: [AffixModifier]
}
