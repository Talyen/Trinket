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
        .disabled(isLocked)
        .trinketArtworkCardButtonStyle()
        .accessibilityIdentifier(AccessibilityID.Play.spireRow(spire.id.rawValue))
    }

    private var orderedSpires: [SpireDefinition] {
        GameContent.spires.orderedForSpiresHub(progress: playerSave.spires, isUnlocked: isSpireUnlocked)
    }

    private func isSpireUnlocked(_ spire: SpireDefinition) -> Bool {
        SpireAttunement.canEnter(
            spire,
            heroes: playerSave.roster.heroes,
            companions: playerSave.roster.companions,
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
        return "\(clearedFloors) / \(spire.floorCount) Floors"
    }
}
