import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct SpiresHubView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        PlayModeHubScreen(
            title: "The Spires",
            accessibilityIdentifier: AccessibilityID.Play.spiresHub
        ) {
            ForEach(GameContent.spires) { spire in
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
            PlayModeArtworkCard(
                title: spire.title,
                subtitle: subtitle(for: spire, isLocked: isLocked),
                symbolName: nil,
                artID: "spire-\(spire.id.rawValue)",
                fallbackArtID: "gameModeExplore",
                isLocked: isLocked
            )
        }
        .disabled(isLocked)
        .trinketQuietTapButtonStyle()
        .accessibilityIdentifier(AccessibilityID.Play.spireRow(spire.id.rawValue))
    }

    private func isSpireUnlocked(_ spire: SpireDefinition) -> Bool {
        SpireAttunement.canEnter(
            spire,
            heroes: appState.roster.heroes,
            companions: appState.roster.companions
        )
    }

    private func subtitle(for spire: SpireDefinition, isLocked: Bool) -> String {
        if isLocked {
            return "Requires \(spire.keyword.rawValue) Abilities"
        }

        let clearedFloors = min(
            appState.spires.highestClearedFloor(for: spire.id.rawValue),
            spire.floorCount
        )
        return "\(clearedFloors) / \(spire.floorCount) Floors"
    }
}
