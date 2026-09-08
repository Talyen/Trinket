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
            title: "The Spires",
            accessibilityIdentifier: AccessibilityID.Play.spiresHub,
        ) {
            ForEach(orderedSpires) { spire in
                spireCard(spire)
            }
        }
    }

    @ViewBuilder
    private func spireCard(_ spire: SpireDefinition) -> some View {
        let isLocked = !isSpireUnlocked(spire)

        NavigationLink {
            SpireClimbView(spireID: spire.id)
        } label: {
            HubArtworkCard(
                title: spire.title,
                subtitle: subtitle(for: spire, isLocked: isLocked),
                symbolName: nil,
                artID: "spire-\(spire.id.rawValue)",
                fallbackArtID: "gameModeExplore",
                isLocked: isLocked,
            )
        }
        .trinketArtworkCardButtonStyle()
        .accessibilityIdentifier(AccessibilityID.Play.spireRow(spire.id.rawValue))
    }

    private var orderedSpires: [SpireDefinition] {
        GameContent.spires.orderedForSpiresHub(progress: playerSave.spires, isUnlocked: isSpireUnlocked)
    }

    private func isSpireUnlocked(_ spire: SpireDefinition) -> Bool {
        SpireAttunement.canEnter(
            spire,
            heroes: playerSave.roster.heroes.filter { playerSave.contentAccess.allowsCombatant($0.id) },
            companions: playerSave.roster.companions.filter { playerSave.contentAccess.allowsCombatant($0.id) },
        )
    }

    private func subtitle(for spire: SpireDefinition, isLocked: Bool) -> String {
        if isLocked {
            return "Requires \(spire.keyword.rawValue) Abilities"
        }

        let clearedFloors = min(
            playerSave.spires.highestClearedFloor(for: spire.id.rawValue),
            spire.floorCount,
        )
        let progress = "\(clearedFloors) / \(spire.floorCount) Floors"
        return playerSave.contentAccess.hasFullGame ? progress : "\(progress) · First \(ContentAccessPolicy.freeSpireFloorCount) free"
    }
}
