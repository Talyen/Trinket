import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var upgradeEventCount = 0
    @State private var recentUpgradeID: HomesteadNodeID?
    @State private var homesteadBuildError: String?

    private var screen: HomesteadScreenState {
        HomesteadScreenState(homestead: appState.homestead.current, roster: appState.roster.current)
    }

    private var allDefinitions: [HomesteadNodeDefinition] {
        GameContent.homesteadNodes
    }

    private var featuredDefinition: HomesteadNodeDefinition? {
        HomesteadProgression.recommendedProject(definitions: allDefinitions, screen: screen)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HomesteadResourceWallet(
                    homestead: screen.homestead,
                    roster: screen.roster,
                    resources: HomesteadProgression.walletResources(for: featuredDefinition, screen: screen)
                )

                if let featuredDefinition {
                    HomesteadFeaturedProjectCard(
                        definition: featuredDefinition,
                        status: screen.projectStatus(for: featuredDefinition),
                        onBuild: { buildOrUpgrade(featuredDefinition) }
                    )
                }

                ForEach(HomesteadNodeCategory.allCases) { category in
                    let definitions = definitions(in: category)
                    if !definitions.isEmpty {
                        HomesteadProjectSection(
                            category: category,
                            definitions: definitions,
                            screen: screen,
                            recentUpgradeID: recentUpgradeID
                        )
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 112)
        }
        .trinketScreenBackground(.homestead)
        .navigationTitle("Homestead")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier(AccessibilityID.Screen.homestead)
        .sensoryFeedback(.success, trigger: upgradeEventCount)
        .homesteadBuildErrorAlert(error: $homesteadBuildError)
    }

    private func buildOrUpgrade(_ definition: HomesteadNodeDefinition) {
        switch HomesteadBuildSupport.buildOrUpgrade(
            definition,
            homestead: appState.homestead,
            roster: appState.roster
        ) {
        case .success:
            recentUpgradeID = definition.id
            upgradeEventCount += 1
            guard !reduceMotion else { return }
            withAnimation(.snappy) {
                recentUpgradeID = definition.id
            }
        case let .failed(message):
            homesteadBuildError = message
        }
    }

    private func definitions(in category: HomesteadNodeCategory) -> [HomesteadNodeDefinition] {
        HomesteadProgression.visibleDefinitions(
            in: category,
            all: allDefinitions,
            homestead: screen.homestead
        )
    }
}
