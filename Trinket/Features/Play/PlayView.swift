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
        .onChange(of: battle.activeBattle?.id) { _, newID in
            if newID == nil {
                restorePlayDestinationIfNeeded()
            }
        }
        .modifier(PlaySessionPresentationModifier(stageMessage: $stageMessage))
    }

    private func restorePlayDestinationIfNeeded() {
        guard restoresPendingDestination else { return }
        guard battle.lifecyclePhase != .active else { return }

        if let destination = play.consumePendingDestination() {
            apply(destination)
        }
    }

    private func apply(_ destination: PlayLaunchDestination) {
        shellSession.playPath = switch destination {
        case .campaign:
            [.campaign]
        case .explore:
            [.explore]
        case .spiresHub:
            [.explore, .spiresHub]
        case .labyrinthMap:
            [.explore, .labyrinthMap]
        case let .spireClimb(spireID):
            [.explore, .spiresHub, .spireClimb(spireID)]
        }
    }
}

extension EnvironmentValues {
    @Entry var isBattleActive = false
    @Entry var presentPlayCombatantDetail: (CombatantCardDetail) -> Void = { _ in }
}
