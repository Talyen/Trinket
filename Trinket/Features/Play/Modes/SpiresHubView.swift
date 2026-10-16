import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct SpiresHubView: View {
    @Environment(PlayerSaveStore.self) private var playerSave

    var body: some View {
        HubGridScaffold(
            title: String(localized: L10n.ui_spireshubview_spires_77de7),
            accessibilityIdentifier: AccessibilityID.Play.spiresHub,
        ) {
            ForEach(orderedSpires) { spire in
                spireCard(spire)
            }
        }
    }

    private func spireCard(_ spire: SpireDefinition) -> some View {
        HubArtworkNavigationLink(
            destination: PlayLaunchDestination.spireClimb(spire.id),
            title: spire.title,
            subtitle: subtitle(for: spire),
            artID: "spire-\(spire.id.rawValue)",
            fallbackArtID: EncounterArtIDs.explorePlayModeID,
            accessibilityIdentifier: AccessibilityID.Play.spireRow(spire.id.rawValue),
        )
    }

    private var orderedSpires: [SpireDefinition] {
        GameContent.spires.orderedForSpiresHub(progress: playerSave.spires)
    }

    private func subtitle(for spire: SpireDefinition) -> String {
        let clearedFloors = SpiresProgress.clampedClearedFloors(
            highestCleared: playerSave.spires.highestClearedFloor(for: spire.id.rawValue),
            floorCount: spire.floorCount,
        )
        return SpiresProgress.floorsText(cleared: clearedFloors, total: spire.floorCount)
    }
}
