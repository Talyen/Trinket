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
    @State private var stageMessage: StageMapMessage?
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
            PlayBattleOverlay(stageMessage: $stageMessage)
        }
        .toolbarVisibility(
            battle.lifecyclePhase == .active || play.currentPostBattleTalentCombatantID != nil ? .hidden : .visible,
            for: .tabBar,
        )
        .environment(\.isBattleActive, battle.lifecyclePhase == .active)
        .environment(\.presentPlayCombatantDetail, battle.presentCombatantDetail)
        .onAppear {
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
        guard restoresPendingDestination else { return }
        guard battle.lifecyclePhase != .active else { return }

        if let destination = play.consumePendingDestination() {
            shellSession.playPath = destination.navigationPath
        }
    }
}

extension EnvironmentValues {
    @Entry var isBattleActive = false
    @Entry var presentPlayCombatantDetail: (CombatantCardDetail) -> Void = { _ in }
}
