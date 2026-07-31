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
    public let shellSession: PlayerShellSessionStore
    public let battle: any BattleRuntime
    public let options: OptionsStore
    public let sfxPlayer: SFXPlayer

    public let journey: JourneyPlayMode
    public let labyrinth: LabyrinthPlayMode
    public let spires: SpiresPlayMode
    public let encounters: EncounterPlayMode

    private let mapScrollFocusSink: MapScrollFocusSink
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
        let graph = PlayModeGraph.assemble(
            playerSave: playerSave,
            battle: battle,
            options: options,
            sfxPlayer: sfxPlayer,
            noteMapScrollFocus: { targetID in focusSink.note(targetID) }
        )
        battleLaunch = graph.battleLaunch
        journey = graph.journey
        labyrinth = graph.labyrinth
        spires = graph.spires
        encounters = graph.encounters
        battleCompletion = graph.battleCompletion
        focusSink.owner = self
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
        battle: any BattleRuntime,
        options: OptionsStore,
        sfxPlayer: SFXPlayer,
        noteMapScrollFocus: @escaping (String) -> Void
    ) -> Assembled {
        let battleLaunch = PlayBattleLaunch(playerSave: playerSave, battle: battle)
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
            battle: battle,
            journey: journey,
            labyrinth: labyrinth,
            spires: spires
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
