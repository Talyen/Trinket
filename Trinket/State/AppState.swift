import Foundation
import Observation
import os
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketPersistence

let appStateLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "AppState"
)

@MainActor
@Observable
final class AppState {
    let playerSave: PlayerSaveStore
    let musicPlayer: MusicPlayer
    var selectedTab: AppTab
    var roster: PlayerRosterStore
    var inventory: PlayerInventoryStore
    var homestead: PlayerHomesteadStore
    var options: OptionsStore
    var battle: BattleSession
    var journey: PlayerJourneyStore
    let sessionState: SessionStateStore
    let initialCollectionCombatantDetail: CombatantDetailContext?
    let initialCollectionItemID: String?

    init(
        environment: AppEnvironment = .shared,
        playerSave: PlayerSaveStore? = nil,
        userDefaults: UserDefaults? = nil
    ) {
        let dependencies = Self.makeBootstrapDependencies(
            environment: environment,
            playerSave: playerSave,
            userDefaults: userDefaults
        )

        self.playerSave = dependencies.playerSave
        musicPlayer = dependencies.musicPlayer
        roster = dependencies.roster
        inventory = dependencies.inventory
        homestead = dependencies.homestead
        options = dependencies.options
        journey = dependencies.journey
        sessionState = dependencies.sessionState
        initialCollectionCombatantDetail = dependencies.initialCollectionCombatantDetail
        initialCollectionItemID = dependencies.initialCollectionItemID
        selectedTab = dependencies.selectedTab
        battle = BattleSession()
        finishBootstrap(environment: environment)
    }

    var shellDataStatusPresentation: ShellDataStatusPresentation? {
        if let persistenceMessage = persistenceStatusMessage {
            return ShellDataStatusPresentation(
                message: persistenceMessage,
                symbolName: "externaldrive.badge.exclamationmark",
                style: .destructive
            )
        }

        return nil
    }

    private var persistenceStatusMessage: String? {
        switch playerSave.lastPersistenceError {
        case .writeFailed:
            return "Couldn't save progress to this device. Your latest changes may be lost if the app closes."
        case let .invalidSave(message):
            return message
        case .none:
            return nil
        }
    }

    var playChapter: Chapter {
        GameContent.chapter(id: journey.current.activeChapterID) ?? GameContent.chapters[0]
    }

    @discardableResult
    func completeStage(
        _ stage: Stage,
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil
    ) -> String {
        do {
            try playerSave.performBatchMutation { save in
                var context = save.stageCompletionContext()
                StageCompletion.complete(
                    stage,
                    hero: hero,
                    pet: pet,
                    battleEarnedGold: battleEarnedGold,
                    materialRewards: materialRewards,
                    in: GameContent.chapters,
                    context: &context
                )
                context.apply(to: &save)
            }
            let scrollTarget = JourneyMapPresentation.scrollFocusID(for: journey.current)
            sessionState.noteMapScrollFocus(scrollTarget)
            return scrollTarget
        } catch {
            appStateLogger.error(
                "Failed to persist stage completion: \(error.localizedDescription, privacy: .public)"
            )
            return JourneyMapPresentation.scrollFocusID(for: journey.current)
        }
    }

    func completeActiveBattle(
        _ configuration: ActiveBattleConfiguration,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]? = nil
    ) {
        guard battle.activeBattle != nil else { return }

        if let stageID = configuration.stageID,
           let stage = GameContent.stage(id: stageID) {
            completeStage(
                stage,
                hero: configuration.hero.combatant,
                pet: configuration.pet.combatant,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards
            )
        } else if battleEarnedGold > 0 {
            grantBattleEarnedGold(battleEarnedGold)
        }
        battle.endBattle()
    }

    func grantBattleEarnedGold(_ amount: Int) {
        guard amount > 0 else { return }
        do {
            try playerSave.performBatchMutation { save in
                save.roster.gold += amount
            }
        } catch {
            appStateLogger.error(
                "Failed to persist battle gold: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func handleBattlePeriodicTick(
        configuration: ActiveBattleConfiguration,
        at date: Date
    ) {
        if let earnedGold = battle.advanceAutoTick(
            at: date,
            journey: journey.current,
            homestead: homestead.current
        ) {
            grantBattleEarnedGold(earnedGold)
            completeActiveBattle(configuration, battleEarnedGold: 0)
        }
    }

    @discardableResult
    func resetGameplayProgress() -> Bool {
        do {
            try playerSave.resetGameplayProgress()
        } catch {
            appStateLogger.error(
                "Failed to reset gameplay progress: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
        battle.endBattle()
        sessionState.clearBattleState()
        sessionState.selectedTab = nil
        selectedTab = .play
        return true
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

struct ShellDataStatusPresentation: Equatable {
    enum Style: Equatable {
        case destructive
        case secondary
    }

    let message: String
    let symbolName: String
    let style: Style
}
