import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct AspectsHubView: View {
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
                ForEach(GameContent.aspects) { aspect in
                    aspectCard(aspect)
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.top, TrinketDesign.Metrics.compactContentTopPadding)
            .padding(.bottom, TrinketDesign.Metrics.extraLargeSpacing)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Aspects")
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground()
        .accessibilityIdentifier(AccessibilityID.Play.aspectsHub)
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
        let hasHero = appState.roster.heroes.contains {
            $0.keywordProfile.contains(aspect.keyword)
        }
        let hasCompanion = appState.roster.companions.contains {
            $0.keywordProfile.contains(aspect.keyword)
        }
        return hasHero && hasCompanion
    }

    private func subtitle(for aspect: AspectDefinition, isLocked: Bool) -> String {
        if isLocked {
            return "Requires at least one Hero and Companion with \(aspect.keyword.rawValue) abilities"
        }

        let clearedFloors = min(
            appState.aspects.highestClearedFloor(for: aspect.id.rawValue),
            aspect.floorCount
        )
        let percentComplete = aspect.floorCount == 0 ? 0 : clearedFloors * 100 / aspect.floorCount
        return "\(percentComplete)% complete · \(clearedFloors) / \(aspect.floorCount) Floors"
    }
}
