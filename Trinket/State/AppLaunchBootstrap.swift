import Foundation
import TrinketContent
import TrinketPersistence

enum AppLaunchBootstrap {
    struct LaunchTargets {
        let selectedTab: AppTab
        let initialCombatantDetail: CombatantDetailContext?
        let initialItemID: String?
        let shouldStartLaunchBattle: Bool
        let restoredBattleStageID: String?
    }

    static func launchTargets(
        environment: AppEnvironment,
        sessionState: SessionStateStore
    ) -> LaunchTargets {
        LaunchTargets(
            selectedTab: selectedTab(environment: environment, sessionState: sessionState),
            initialCombatantDetail: combatantDetail(for: environment.launchScreen),
            initialItemID: collectionItemID(for: environment.launchScreen),
            shouldStartLaunchBattle: environment.launchScreen == .battle,
            restoredBattleStageID: environment.launchScreen == .battle
                ? nil
                : sessionState.activeBattleStageID
        )
    }

    static func selectedTab(
        environment: AppEnvironment,
        sessionState: SessionStateStore
    ) -> AppTab {
        if let envTab = environment.launchTab {
            return envTab
        }
        if let launchScreen = environment.launchScreen {
            return tab(for: launchScreen)
        }
        return sessionState.selectedTab ?? .play
    }

    static func tab(for launchScreen: LaunchScreen) -> AppTab {
        switch launchScreen {
        case .heroDetail, .petDetail, .itemDetail:
            return .collection
        case .battle:
            return .play
        case .options:
            return .options
        }
    }

    static func combatantDetail(for launchScreen: LaunchScreen?) -> CombatantDetailContext? {
        switch launchScreen {
        case let .heroDetail(id):
            CombatantDetailContext(kind: .hero, combatantID: id)
        case let .petDetail(id):
            CombatantDetailContext(kind: .pet, combatantID: id)
        case .itemDetail, .battle, .options, .none:
            nil
        }
    }

    static func collectionItemID(for launchScreen: LaunchScreen?) -> String? {
        switch launchScreen {
        case let .itemDetail(id):
            id
        case .heroDetail, .petDetail, .battle, .options, .none:
            nil
        }
    }
}
