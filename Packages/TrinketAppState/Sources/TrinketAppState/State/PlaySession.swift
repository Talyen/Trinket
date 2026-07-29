import Observation
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
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
    public let battle: BattleSession
    public let options: OptionsStore
    public let sfxPlayer: SFXPlayer

    public let journey: JourneyPlayMode
    public let labyrinth: LabyrinthPlayMode
    public let spires: SpiresPlayMode
    public let encounters: EncounterPlayMode

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
        battle: BattleSession,
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

        // Bridge focus before `self` is fully formed — modes call through the box.
        let focusBridge = MapScrollFocusBox()
        let graph = PlayModeGraph.assemble(
            playerSave: playerSave,
            battle: battle,
            options: options,
            sfxPlayer: sfxPlayer,
            noteMapScrollFocus: { targetID in
                focusBridge.note?(targetID)
            }
        )
        battleLaunch = graph.battleLaunch
        journey = graph.journey
        labyrinth = graph.labyrinth
        spires = graph.spires
        encounters = graph.encounters
        battleCompletion = graph.battleCompletion
        focusBridge.note = { [weak self] targetID in
            self?.noteMapScrollFocus(targetID)
        }
    }

    public func consumePendingDestination() -> PlayLaunchDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }

    func queueReturnToBattleOrigin(from origin: PlayBattleOrigin?) {
        pendingDestination = PlayLaunchDestination.returning(from: origin)
    }

    public func endBattleReturningToOrigin() {
        let origin = battle.activeBattle?.runKey.flatMap(PlayBattleOrigin.init(runKey:))
        queueReturnToBattleOrigin(from: origin)
        shellSession.selectedTab = .play
        battle.endBattle()
    }

    public func noteMapScrollFocus(_ targetID: String) {
        mapScrollStageID = targetID
        let nextRevision = (mapScrollFocus?.revision ?? 0) + 1
        mapScrollFocus = MapScrollFocus(stageID: targetID, revision: nextRevision)
    }

    /// Persists victory rewards and ends the battle only when persistence succeeds.
    @discardableResult
    public func completeActiveBattle(
        _ configuration: ActiveBattleConfiguration,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]? = nil
    ) -> Bool {
        battleCompletion.completeActiveBattle(
            configuration,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards,
            queueReturnToOrigin: { [weak self] origin in
                self?.queueReturnToBattleOrigin(from: origin)
            }
        )
    }

    func clearTransientState() {
        battle.endBattle()
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
        battle: BattleSession,
        options: OptionsStore,
        sfxPlayer: SFXPlayer,
        noteMapScrollFocus: @escaping (String) -> Void
    ) -> Assembled {
        let battleLaunch = PlayBattleLaunch(playerSave: playerSave, battle: battle)
        let focusBox = MapScrollFocusBox()
        let deferredFocus: (String) -> Void = { targetID in
            focusBox.note?(targetID)
        }
        let completionPorts = EncounterCompletionPorts()

        let encounters = EncounterPlayMode(
            playerSave: playerSave,
            battle: battle,
            options: options,
            sfxPlayer: sfxPlayer,
            noteMapScrollFocus: deferredFocus,
            completionPorts: completionPorts
        )
        let journey = JourneyPlayMode(
            playerSave: playerSave,
            battle: battle,
            battleLaunch: battleLaunch,
            noteMapScrollFocus: deferredFocus,
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
            battle: battle,
            journey: journey,
            labyrinth: labyrinth,
            spires: spires
        )

        completionPorts.completeJourneyStage = { [weak journey] stage in
            journey?.completeStageOrPersistFailure(stage)
        }
        completionPorts.completeLabyrinthNode = { [weak labyrinth] nodeID in
            labyrinth?.completeNodeOrPersistFailure(nodeID: nodeID)
        }
        focusBox.note = noteMapScrollFocus

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

// Concurrency-Safety: `@unchecked Sendable` — `note` is written once on the
// MainActor after modes are constructed and invoked only from mode presentation
// paths on the MainActor; never called from a concurrent executor.
private final class MapScrollFocusBox: @unchecked Sendable {
    var note: ((String) -> Void)?
}
