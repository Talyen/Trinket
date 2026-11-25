import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct ExploreHubView: View {
    @Environment(PlayerSaveStore.self) private var playerSave

    var body: some View {
        HubGridScaffold(
            title: String(localized: L10n.ui_explorehubview_explore_3b739),
            accessibilityIdentifier: AccessibilityID.Play.exploreHub,
            fillsAvailableWidth: true,
        ) {
            ExploreMode.spires.card(subtitle: spiresProgressSubtitle)
            ExploreMode.labyrinth.card(subtitle: String(localized: L10n.ui_explorehubview_floor_1_699ae(
                "\(max(1, playerSave.labyrinth.currentFloorNumber))",
            )))
            ExploreMode.contracts.card()
            ExploreMode.voyage.card()
        }
    }

    private var spiresProgressSubtitle: String {
        let totalFloors = GameContent.spires.reduce(0) { partialResult, spire in
            partialResult + spire.floorCount
        }
        let clearedFloors = GameContent.spires.reduce(0) { partialResult, spire in
            partialResult + SpiresProgress.clampedClearedFloors(
                highestCleared: playerSave.spires.highestClearedFloor(for: spire.id.rawValue),
                floorCount: spire.floorCount,
            )
        }
        return SpiresProgress.floorsText(cleared: clearedFloors, total: totalFloors)
    }
}

@MainActor
struct ExploreMode {
    static let voyage = Self(
        destination: .voyage,
        title: L10n.ui_explorehubview_voyage_10d91,
        artworkID: "gameModeVoyage",
        accessibilityIdentifier: AccessibilityID.Voyage.modeCard,
    )

    static let spires = Self(
        destination: .spiresHub,
        title: L10n.ui_explorehubview_spires_77de7,
        artworkID: "gameModeSpires",
        fallbackArtID: EncounterArtIDs.explorePlayModeID,
        accessibilityIdentifier: AccessibilityID.Play.spiresModeCard,
    )

    static let labyrinth = Self(
        destination: .labyrinthMap,
        title: L10n.ui_explorehubview_labyrinth_df308,
        artworkID: "gameModeLabyrinth",
        fallbackArtID: EncounterArtIDs.explorePlayModeID,
        accessibilityIdentifier: AccessibilityID.Play.labyrinthModeCard,
    )

    static let contracts = Self(
        destination: .contracts,
        title: L10n.ui_explorehubview_contracts_0488a,
        artworkID: EncounterArtIDs.contractsHeroID,
        accessibilityIdentifier: AccessibilityID.Play.contractsModeCard,
    )

    static let campaignCompletionOrder: [Self] = [.voyage, .spires, .labyrinth, .contracts]

    let destination: PlayLaunchDestination
    private let title: LocalizedStringResource
    let artworkID: String
    private var fallbackArtID: String?
    private let accessibilityIdentifier: String

    func card(subtitle: String? = nil) -> some View {
        HubArtworkNavigationLink(
            destination: destination,
            title: String(localized: title),
            subtitle: subtitle,
            artID: artworkID,
            fallbackArtID: fallbackArtID,
            accessibilityIdentifier: accessibilityIdentifier,
        )
    }
}
