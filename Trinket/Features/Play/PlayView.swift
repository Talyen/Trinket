import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketBattleRuntime
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct PlayView: View {
    @Environment(PlaySession.self) private var play
    @Environment(BattleSession.self) private var battle
    @State private var stageMessage: StageMapMessage?
    @State private var navigationPath: [PlayLaunchDestination] = []

    var body: some View {
        // Keep browsing chrome and battle overlay as separate observation scopes.
        // A single `@Bindable` BattleSession here rebuilt the campaign stack on every
        // overlay/sheet write (enemy detail, ability, log).
        ZStack {
            PlayBrowsingStack(
                navigationPath: $navigationPath,
                stageMessage: $stageMessage
            )
            PlayBattleOverlay(stageMessage: $stageMessage)
        }
        .environment(\.isBattleActive, battle.lifecyclePhase == .active)
        .environment(\.presentPlayCombatantDetail, battle.presentCombatantDetail)
        .onAppear {
            restorePlayDestinationIfNeeded()
        }
        .onChange(of: play.shellSession.selectedTab) { previousTab, newTab in
            guard !play.shellSession.isShellWarmupActive else { return }
            guard newTab == .play, previousTab != .play else { return }
            // A normal Play-tab visit is a fresh choice. Pending destinations
            // are consumed only for battle/deep-link restoration below.
            guard battle.lifecyclePhase != .active else { return }
            restorePlayDestinationIfNeeded(resetForNormalEntry: true)
        }
        .onChange(of: battle.activeBattle?.id) { _, newID in
            if newID == nil {
                restorePlayDestinationIfNeeded()
            }
        }
        .modifier(PlaySessionPresentationModifier(stageMessage: $stageMessage))
    }

    /// Prefer pending post-battle / launch destinations. Otherwise leave the
    /// explicit path empty so the mode chooser is the Play root.
    private func restorePlayDestinationIfNeeded(resetForNormalEntry: Bool = false) {
        guard battle.lifecyclePhase != .active else { return }

        if let destination = play.consumePendingDestination() {
            apply(destination)
            return
        }

        if resetForNormalEntry {
            navigationPath.removeAll()
        }
    }

    private func apply(_ destination: PlayLaunchDestination) {
        navigationPath = switch destination {
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
