import BattleEngine
import Observation
import TrinketBattleFeature
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence

/// Stateful owner of Play-tab orchestration and transient encounter flows.
///
/// AppState composes this session, while Play features observe it directly.
@MainActor
@Observable
public final class PlaySession {
    public let playerSave: PlayerSaveStore
    public let shellSession: PlayerShellSessionStore
    public let battle: BattleSession
    public let options: OptionsStore
    public let sfxPlayer: SFXPlayer

    public var activeMysteryEncounter: MysteryEncounterSession?
    public var activeShopEncounter: ShopEncounterSession?
    public var activeLabyrinthNodeSession: LabyrinthNodeSession?

    public private(set) var pendingDestination: PlayLaunchDestination?
    public private(set) var mapScrollFocus: MapScrollFocus?

    public var journey: JourneyProgressState {
        get { playerSave.journey }
        set { playerSave.journey = newValue }
    }

    public var roster: PlayerRosterState {
        get { playerSave.roster }
        set { playerSave.roster = newValue }
    }

    public var inventory: PlayerInventoryState {
        get { playerSave.inventory }
        set { playerSave.inventory = newValue }
    }

    public var homestead: PlayerHomesteadState {
        get { playerSave.homestead }
        set { playerSave.homestead = newValue }
    }

    public var spires: PlayerSpiresState {
        get { playerSave.spires }
        set { playerSave.spires = newValue }
    }

    public var labyrinth: PlayerLabyrinthState {
        get { playerSave.labyrinth }
        set { playerSave.labyrinth = newValue }
    }

    public var mapScrollStageID: String? {
        get { shellSession.mapScrollStageID }
        set { shellSession.mapScrollStageID = newValue }
    }

    public var lastPlayMode: PlayerShellSessionPlayMode {
        get { shellSession.lastPlayMode }
        set { shellSession.lastPlayMode = newValue }
    }

    public var selectedTab: AppTab {
        get { AppTab(shellSessionTab: shellSession.selectedTab) ?? .play }
        set { shellSession.selectedTab = PlayerShellSessionTab(rawValue: newValue.rawValue) ?? .play }
    }

    public var playChapter: Chapter {
        GameContent.chapter(id: journey.activeChapterID) ?? GameContent.chapters[0]
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

    public func presentCombatLog() {
        battle.presentBattleLog()
    }

    public func noteMapScrollFocus(_ targetID: String) {
        mapScrollStageID = targetID
        let nextRevision = (mapScrollFocus?.revision ?? 0) + 1
        mapScrollFocus = MapScrollFocus(stageID: targetID, revision: nextRevision)
    }

    func clearTransientState() {
        battle.endBattle()
        activeMysteryEncounter = nil
        activeShopEncounter = nil
        activeLabyrinthNodeSession = nil
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

    #if DEBUG
    @discardableResult
    func unlockAllContent() -> Bool {
        do {
            try playerSave.unlockAllContent()
        } catch {
            appStateLogger.error(
                "Failed to unlock all content: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
        clearTransientState()
        return true
    }
    #endif
}
