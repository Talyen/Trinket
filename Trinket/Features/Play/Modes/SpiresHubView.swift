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

        HubArtworkNavigationLink(
            destination: PlayLaunchDestination.spireClimb(spire.id),
            title: spire.title,
            subtitle: subtitle(for: spire, isLocked: isLocked),
            artID: "spire-\(spire.id.rawValue)",
            fallbackArtID: "gameModeExplore",
            isLocked: isLocked,
            accessibilityIdentifier: AccessibilityID.Play.spireRow(spire.id.rawValue),
        )
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

        let clearedFloors = SpiresProgress.clampedClearedFloors(
            highestCleared: playerSave.spires.highestClearedFloor(for: spire.id.rawValue),
            floorCount: spire.floorCount,
        )
        let progress = SpiresProgress.floorsText(cleared: clearedFloors, total: spire.floorCount)
        return playerSave.contentAccess.hasFullGame ? progress : "\(progress) · First \(ContentAccessPolicy.freeSpireFloorCount) free"
    }
}
