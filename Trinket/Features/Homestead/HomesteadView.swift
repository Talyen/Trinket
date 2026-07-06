import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var buildActions = HomesteadBuildActions()
    @State private var recentUpgradeID: HomesteadNodeID?

    private var homestead: PlayerHomesteadState { appState.homestead.current }
    private var roster: PlayerRosterState { appState.roster.current }

    private var allDefinitions: [HomesteadNodeDefinition] {
        GameContent.homesteadNodes
    }

    private var featuredDefinition: HomesteadNodeDefinition? {
        HomesteadProgression.recommendedProject(
            definitions: allDefinitions,
            homestead: homestead,
            roster: roster
        )
    }

    var body: some View {
        @Bindable var buildActions = buildActions

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HomesteadResourceWallet(
                    homestead: homestead,
                    roster: roster,
                    resources: HomesteadProgression.walletResources(
                        for: featuredDefinition,
                        homestead: homestead,
                        roster: roster
                    )
                )

                if let featuredDefinition {
                    HomesteadProjectCard(
                        definition: featuredDefinition,
                        status: HomesteadProjectStatus(
                            definition: featuredDefinition,
                            homestead: homestead,
                            roster: roster
                        ),
                        style: .featured(onBuild: { buildOrUpgrade(featuredDefinition) })
                    )
                }

                ForEach(HomesteadNodeCategory.allCases) { category in
                    let definitions = definitions(in: category)
                    if !definitions.isEmpty {
                        HomesteadProjectSection(
                            category: category,
                            definitions: definitions,
                            homestead: homestead,
                            roster: roster,
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
        .sensoryFeedback(.success, trigger: buildActions.upgradeEventCount)
        .homesteadBuildErrorAlert(error: $buildActions.error)
    }

    private func buildOrUpgrade(_ definition: HomesteadNodeDefinition) {
        buildActions.perform(
            definition,
            homestead: appState.homestead,
            roster: appState.roster,
            onSuccess: { nodeID in
                recentUpgradeID = nodeID
                guard !reduceMotion else { return }
                withAnimation(.snappy) {
                    recentUpgradeID = nodeID
                }
            }
        )
    }

    private func definitions(in category: HomesteadNodeCategory) -> [HomesteadNodeDefinition] {
        HomesteadProgression.visibleDefinitions(
            in: category,
            all: allDefinitions,
            homestead: homestead
        )
    }
}
