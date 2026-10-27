import BattleEngine
import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct PlayView: View {
    @Environment(PlaySession.self) private var play
    @Environment(ShellSession.self) private var shellSession
    @Environment(BattleSession.self) private var battle
    @Environment(EncounterPlayMode.self) private var encounters
    @Environment(\.isLaunchPresentationReady) private var isLaunchPresentationReady
    @State private var stageMessage: StageMapMessage?
    @State private var restoredStack = false
    let restoresPendingDestination: Bool

    init(restoresPendingDestination: Bool = true) {
        self.restoresPendingDestination = restoresPendingDestination
    }

    var body: some View {
        @Bindable var shellSession = shellSession

        ZStack {
            PlayBrowsingStack(
                navigationPath: $shellSession.playPath,
                stageMessage: $stageMessage,
            )
            .id(restoredStack)
            PlayBattleOverlay(stageMessage: $stageMessage)
        }
        .toolbarVisibility(
            battle.lifecyclePhase == .active || play.currentPostBattleTalentCombatantID != nil ? .hidden : .visible,
            for: .tabBar,
        )
        .environment(\.isBattleActive, battle.lifecyclePhase == .active)
        .environment(\.presentPlayCombatantDetail, battle.presentCombatantDetail)
        .task(id: isLaunchPresentationReady) {
            restorePlayDestinationIfNeeded()
        }
        .onChange(of: play.shellSession.selectedTab) { previousTab, newTab in
            guard newTab == .play, previousTab != .play else { return }
            guard battle.lifecyclePhase != .active else { return }
            restorePlayDestinationIfNeeded()
        }
        .modifier(PlaySessionPresentationModifier(stageMessage: $stageMessage))
    }

    private func restorePlayDestinationIfNeeded() {
        // Let the retained tab root finish its launch layout before pushing a destination.
        guard restoresPendingDestination, isLaunchPresentationReady else { return }
        guard battle.lifecyclePhase != .active else { return }
        // Never overwrite the browsing path under an encounter cover; the
        // pending destination stays queued until the encounter clears.
        guard encounters.activeMysteryEncounter == nil, encounters.activeShopEncounter == nil else { return }

        if let destination = play.consumePendingDestination() {
            shellSession.playPath = destination.navigationPath
            // Mount the stack with its restored path after launch layout has
            // settled; some SwiftUI runtimes miss an early multi-level push.
            restoredStack.toggle()
        }
    }
}

extension EnvironmentValues {
    @Entry var isBattleActive = false
    @Entry var presentPlayCombatantDetail: (CombatantCardDetail) -> Void = { _ in }
}
