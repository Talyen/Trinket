import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct PlayBrowsingStack: View {
    @Environment(PlaySession.self) private var play
    @Environment(JourneyPlayMode.self) private var journey
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.isBattleActive) private var isBattleActive
    @Environment(\.presentPlayCombatantDetail) private var presentPlayCombatantDetail
    @Binding var navigationPath: [PlayLaunchDestination]
    @Binding var stageMessage: StageMapMessage?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            PlayModeHubView(
                onOpenCampaign: { openMode(.campaign) },
                onOpenExplore: { openMode(.explore) },
            )
            .navigationDestination(for: PlayLaunchDestination.self) { destination in
                destinationView(for: destination)
            }
        }
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

    private func openMode(_ destination: PlayLaunchDestination) -> Bool {
        guard !isBattleActive else { return false }
        navigationPath.append(destination)
        return true
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
