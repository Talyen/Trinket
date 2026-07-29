import Observation
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

/// Play-tab shell and mode registry: navigation, shared battle launch, and victory routing.
///
/// Mode-specific flow lives on `journey`, `labyrinth`, `spires`, and `encounters`.
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

        let battleLaunch = PlayBattleLaunch(playerSave: playerSave, battle: battle)
        self.battleLaunch = battleLaunch

        // Deferred focus wiring: modes capture this box before `self` can form a weak ref.
        // Concurrency-Safety: `@unchecked Sendable` — `note` is written once on the
        // MainActor after modes are constructed and invoked only from mode presentation
        // paths on the MainActor; never called from a concurrent executor.
        final class MapScrollFocusBox: @unchecked Sendable {
            var note: ((String) -> Void)?
        }
        let focusBox = MapScrollFocusBox()
        let noteMapScrollFocus: (String) -> Void = { targetID in
            focusBox.note?(targetID)
        }

        let journey = JourneyPlayMode(
            playerSave: playerSave,
            battle: battle,
            battleLaunch: battleLaunch,
            noteMapScrollFocus: noteMapScrollFocus
        )
        let labyrinth = LabyrinthPlayMode(
            playerSave: playerSave,
            battle: battle,
            battleLaunch: battleLaunch
        )
        let spires = SpiresPlayMode(
            playerSave: playerSave,
            battle: battle,
            battleLaunch: battleLaunch
        )
        let encounters = EncounterPlayMode(
            playerSave: playerSave,
            battle: battle,
            options: options,
            sfxPlayer: sfxPlayer,
            noteMapScrollFocus: noteMapScrollFocus
        )
        self.journey = journey
        self.labyrinth = labyrinth
        self.spires = spires
        self.encounters = encounters

        journey.bind(encounters: encounters)
        labyrinth.bind(encounters: encounters)
        encounters.bindCompletion(
            completeJourneyStage: { [weak journey] stage in
                journey?.completeStageOrPersistFailure(stage)
            },
            completeLabyrinthNode: { [weak labyrinth] nodeID in
                labyrinth?.completeNodeOrPersistFailure(nodeID: nodeID)
            }
        )
        focusBox.note = { [weak self] targetID in
            self?.noteMapScrollFocus(targetID)
        }
    }

    public func consumePendingDestination() -> PlayLaunchDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }

    func queueReturnToBattleOrigin(from token: ActiveBattleResumeToken?) {
        pendingDestination = PlayLaunchDestination.returning(from: token)
    }

    public func endBattleReturningToOrigin() {
        queueReturnToBattleOrigin(from: battle.activeBattle?.resumeToken)
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
        guard battle.activeBattle != nil else { return false }

        let hero = configuration.hero.combatant
        let companion = configuration.companion.combatant
        let persisted: Bool = switch configuration.resumeToken {
        case .journey:
            journey.persistVictory(
                for: configuration,
                hero: hero,
                companion: companion,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards
            )
        case .spire:
            spires.persistVictory(
                for: configuration,
                hero: hero,
                companion: companion,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards
            )
        case .labyrinth:
            labyrinth.persistVictory(
                for: configuration,
                hero: hero,
                companion: companion,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards
            )
        case .none:
            battleEarnedGold > 0 ? grantBattleEarnedGold(battleEarnedGold) : true
        }
        if persisted {
            queueReturnToBattleOrigin(from: configuration.resumeToken)
            battle.endBattle()
        }
        return persisted
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
