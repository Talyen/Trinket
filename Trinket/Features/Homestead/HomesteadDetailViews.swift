import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct HomesteadNodeDetailView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @State private var build = HomesteadBuildControl()

    let definition: HomesteadNodeDefinition

    private var homestead: PlayerHomesteadState {
        playerSave.homestead
    }

    private var roster: PlayerRosterState {
        playerSave.roster
    }

    private var status: HomesteadProjectStatus {
        HomesteadProjectStatus(definition: definition, homestead: homestead, roster: roster)
    }

    var body: some View {
        HomesteadHeroScreen(
            title: definition.title,
            homestead: homestead,
            roster: roster,
            bottomPadding: TrinketDesign.Metrics.extraLargeSpacing,
        ) {
            HomesteadBuildingArtwork(definition: definition, variant: .full)
                .saturation(status.isUnlocked ? 1 : 0)
                .opacity(status.isUnlocked ? 1 : 0.66)
                .animation(HomesteadMotion.nodeSettle, value: status.isUnlocked)
        } bodyContent: {
            HomesteadTierPath(
                definition: definition,
                status: status,
                onBuild: buildOrUpgrade,
            )
        }
        .accessibilityIdentifier(AccessibilityID.Homestead.nodeDetail(title: definition.title))
        .appFramePacingSignpost(
            AppFramePacingSignposts.Name.navigationPush,
            isActive: true,
        )
        .onAppear {
            AppFramePacingSignposts.event(
                AppFramePacingSignposts.Name.navigationPush,
                detail: "homestead=\(definition.id)",
            )
        }
        .trinketSensoryFeedback(
            .success,
            trigger: build.upgradeEventCount,
            enabled: options.hapticsEnabled,
        )
        .homesteadBuildErrorAlert(build: $build)
    }

    private func buildOrUpgrade() {
        build.perform(definition, saveStore: playerSave)
    }
}
