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
    @State private var pinnedArtwork: [String] = []

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
        .task(id: artworkPinKey) {
            await refreshArtworkPins()
        }
        .onDisappear {
            PreparedArtworkCache.shared.releasePins(names: pinnedArtwork)
            pinnedArtwork = []
        }
    }

    private var artworkPinKey: [String] {
        guard let art = ArtCatalog.backgroundArtByID[definition.id.rawValue] else { return [] }
        return [art.imageName, art.thumbnailImageName].compactMap(\.self)
    }

    private func refreshArtworkPins() async {
        let next = Array(Set(artworkPinKey)).sorted()
        let previous = Set(pinnedArtwork)
        let added = Set(next).subtracting(previous)
        let removed = previous.subtracting(Set(next))
        if !added.isEmpty {
            let addedNames = Array(added)
            await PreparedArtworkCache.shared.prepareAndPin(names: addedNames)
            guard !Task.isCancelled else {
                PreparedArtworkCache.shared.releasePins(names: addedNames)
                return
            }
        }
        guard !Task.isCancelled else { return }
        if !removed.isEmpty {
            PreparedArtworkCache.shared.releasePins(names: Array(removed))
        }
        pinnedArtwork = next
    }

    private func buildOrUpgrade() {
        build.perform(definition, saveStore: playerSave)
    }
}
