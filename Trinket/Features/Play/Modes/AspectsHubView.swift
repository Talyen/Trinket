import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct AspectsHubView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        PlayModeHubScreen(
            title: "Aspects",
            accessibilityIdentifier: AccessibilityID.Play.aspectsHub
        ) {
            ForEach(GameContent.aspects) { aspect in
                aspectCard(aspect)
            }
        }
    }

    @ViewBuilder
    private func aspectCard(_ aspect: AspectDefinition) -> some View {
        let isLocked = !isAspectUnlocked(aspect)

        NavigationLink {
            AspectClimbView(aspectID: aspect.id)
        } label: {
            PlayModeArtworkCard(
                title: aspect.title,
                subtitle: subtitle(for: aspect, isLocked: isLocked),
                symbolName: nil,
                artID: "aspect-\(aspect.id.rawValue)",
                fallbackArtID: "gameModeExplore",
                isLocked: isLocked
            )
        }
        .disabled(isLocked)
        .trinketQuietTapButtonStyle()
        .accessibilityIdentifier(AccessibilityID.Play.aspectRow(aspect.id.rawValue))
    }

    private func isAspectUnlocked(_ aspect: AspectDefinition) -> Bool {
        AspectAttunement.canEnter(
            aspect,
            heroes: appState.roster.heroes,
            companions: appState.roster.companions
        )
    }

    private func subtitle(for aspect: AspectDefinition, isLocked: Bool) -> String {
        if isLocked {
            return "Requires Hero/Companion with \(aspect.keyword.rawValue) abilities"
        }

        let clearedFloors = min(
            appState.aspects.highestClearedFloor(for: aspect.id.rawValue),
            aspect.floorCount
        )
        return "\(clearedFloors) / \(aspect.floorCount) Floors"
    }
}
