import SwiftUI

@MainActor
@Observable
final class AppState {
    let playerSave: PlayerSaveStore
    var selectedTab: AppTab
    var roster: PlayerRosterStore
    var inventory: PlayerInventoryStore
    var options: OptionsStore
    var battle: BattleSession
    var journey: PlayerJourneyStore

    init(playerSave: PlayerSaveStore? = nil) {
        let env = AppEnvironment.shared
        let fileStore = PlayerSaveFileStore()
        if env.resetState {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
            fileStore.deleteSave()
        }

        let resolvedPlayerSave = playerSave ?? PlayerSaveStore(fileStore: fileStore)
        if env.seedTestProgress {
            resolvedPlayerSave.applyTestSeed()
        }

        self.playerSave = resolvedPlayerSave
        roster = PlayerRosterStore(saveStore: resolvedPlayerSave)
        inventory = PlayerInventoryStore(saveStore: resolvedPlayerSave)
        options = OptionsStore()
        battle = BattleSession()
        journey = PlayerJourneyStore(saveStore: resolvedPlayerSave)
        selectedTab = env.launchTab ?? Self.defaultTab(for: env.launchScreen)
        seedJourneyProgress(completedStageIDs: env.completedStageIDs)
    }

    func resetGameplayProgress() {
        playerSave.resetGameplayProgress()
    }

    private func seedJourneyProgress(completedStageIDs: [String]) {
        guard !completedStageIDs.isEmpty else { return }
        journey.current = .initial

        let stagesByID = Dictionary(
            uniqueKeysWithValues: GameContent.chapters.flatMap(\.stages).map { ($0.id, $0) }
        )
        completedStageIDs.compactMap { stagesByID[$0] }.forEach { stage in
            journey.complete(stage, in: GameContent.chapters)
            journey.markRewardsClaimed(for: stage)
        }
    }

    private static func defaultTab(for launchScreen: LaunchScreen?) -> AppTab {
        switch launchScreen {
        case .heroDetail, .petDetail, .itemDetail:
            return .collection
        case .battle:
            return .play
        case .options:
            return .options
        case .none:
            return .play
        }
    }
}
