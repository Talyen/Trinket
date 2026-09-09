import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct PlayBrowsingStack: View {
    @Environment(PlaySession.self) private var play
    @Environment(JourneyPlayMode.self) private var journey
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @Environment(\.isBattleActive) private var isBattleActive
    @Environment(\.presentPlayCombatantDetail) private var presentPlayCombatantDetail
    @State private var modeSelectionTrigger = 0
    @Binding var navigationPath: [PlayLaunchDestination]
    @Binding var stageMessage: StageMapMessage?

    var body: some View {
        NavigationStack(path: browsingPath) {
            PlayModeHubView()
                .navigationDestination(for: PlayLaunchDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .trinketSensoryFeedback(.selection, trigger: modeSelectionTrigger, enabled: options.hapticsEnabled)
    }

    private var browsingPath: Binding<[PlayLaunchDestination]> {
        Binding(
            get: { navigationPath },
            set: { newPath in
                if navigationPath.isEmpty, !newPath.isEmpty {
                    guard !isBattleActive else { return }
                    modeSelectionTrigger &+= 1
                }
                navigationPath = newPath
            },
        )
    }

    @ViewBuilder
    private func destinationView(for destination: PlayLaunchDestination) -> some View {
        switch destination {
        case .campaign:
            ChapterStageSelectView(
                onStageTap: handleStageTap,
                onEnemyTap: showEnemyDetails(for:),
            )
        case .explore:
            ExploreHubView()
        case .spiresHub:
            SpiresHubView()
        case .labyrinthMap:
            LabyrinthMapView()
        case .contracts:
            ContractsBoardView()
        case let .spireClimb(spireID):
            SpireClimbView(spireID: spireID)
        }
    }

    private func handleStageTap(_ stage: Stage) -> Bool {
        guard playerSave.journey.isActive(stage) else { return false }
        let interval = AppFramePacingSignposts.signposter.beginInterval(
            AppFramePacingSignposts.Name.stageSelectBattleActivate,
        )
        defer {
            AppFramePacingSignposts.signposter.endInterval(
                AppFramePacingSignposts.Name.stageSelectBattleActivate,
                interval,
            )
        }
        AppFramePacingSignposts.event(
            AppFramePacingSignposts.Name.stageSelectBattleActivate,
            detail: "stage=\(stage.id)",
        )
        if let message = journey.handleStagePrimaryAction(for: stage) {
            stageMessage = message
            return false
        }
        return true
    }

    private func showEnemyDetails(for stage: Stage) {
        guard let detail = enemyDetail(for: stage) else { return }
        presentPlayCombatantDetail(detail)
    }

    private func enemyDetail(for stage: Stage) -> CombatantCardDetail? {
        guard let encounter = journey.resolvedEncounter(for: stage) else { return nil }

        return CombatantCardDetail(
            combatant: encounter.combatant,
        )
    }
}
