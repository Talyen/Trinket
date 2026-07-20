import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Temporary Explore landing page. The eventual world map can replace this
/// hub without changing the Play tab's top-level Campaign/Explore contract.
struct ExploreHubView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [
                GridItem(.flexible(), spacing: TrinketDesign.Metrics.largeSpacing),
                GridItem(.flexible(), spacing: TrinketDesign.Metrics.largeSpacing)
            ]
        }
        return [GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: TrinketDesign.Metrics.largeSpacing) {
                NavigationLink(value: PlayLaunchDestination.aspectsHub) {
                    PlayModeArtworkCard(
                        title: "Aspects",
                        subtitle: aspectsProgressSubtitle,
                        symbolName: nil,
                        artID: "aspect-aureateChoir",
                        fallbackArtID: "gameModeExplore"
                    )
                }
                .accessibilityIdentifier(AccessibilityID.Play.aspectsModeCard)
                .trinketQuietTapButtonStyle()

                NavigationLink(value: PlayLaunchDestination.labyrinthMap) {
                    PlayModeArtworkCard(
                        title: "Labyrinth",
                        subtitle: "Floor \(max(1, appState.labyrinth.currentFloorNumber))",
                        symbolName: nil,
                        artID: "gameModeLabyrinth",
                        fallbackArtID: "gameModeExplore"
                    )
                }
                .accessibilityIdentifier(AccessibilityID.Play.labyrinthModeCard)
                .trinketQuietTapButtonStyle()
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.top, TrinketDesign.Metrics.compactContentTopPadding)
            .padding(.bottom, TrinketDesign.Metrics.extraLargeSpacing)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground()
        .accessibilityIdentifier(AccessibilityID.Play.exploreHub)
    }

    private var aspectsProgressSubtitle: String {
        let totalFloors = GameContent.aspects.reduce(0) { partialResult, aspect in
            partialResult + aspect.floorCount
        }
        let clearedFloors = GameContent.aspects.reduce(0) { partialResult, aspect in
            partialResult + min(
                appState.aspects.highestClearedFloor(for: aspect.id.rawValue),
                aspect.floorCount
            )
        }
        let percentComplete = totalFloors == 0 ? 0 : clearedFloors * 100 / totalFloors
        return "\(percentComplete)% complete · \(clearedFloors) / \(totalFloors) Floors"
    }
}
