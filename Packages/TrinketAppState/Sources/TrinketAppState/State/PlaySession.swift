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

        let journey = JourneyPlayMode()
        let labyrinth = LabyrinthPlayMode()
        let spires = SpiresPlayMode()
        let encounters = EncounterPlayMode()
        self.journey = journey
        self.labyrinth = labyrinth
        self.spires = spires
        self.encounters = encounters

        journey.attach(to: self)
        labyrinth.attach(to: self)
        spires.attach(to: self)
        encounters.attach(to: self)
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

    var canBeginTransientEncounter: Bool {
        battle.activeBattle == nil
            && encounters.activeShopEncounter == nil
            && encounters.activeMysteryEncounter == nil
            && labyrinth.activeNodeSession == nil
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
