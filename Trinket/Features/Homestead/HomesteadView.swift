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

    private var homesteadState: PlayerHomesteadState {
        appState.homestead.current
    }

    private var rosterState: PlayerRosterState {
        appState.roster.current
    }

    private var allDefinitions: [HomesteadNodeDefinition] {
        GameContent.homesteadNodes
    }

    private var featuredDefinition: HomesteadNodeDefinition? {
        HomesteadProgression.recommendedProject(
            definitions: allDefinitions,
            homestead: homesteadState,
            roster: rosterState
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HomesteadResourceWallet(
                    homestead: homesteadState,
                    roster: rosterState,
                    resources: HomesteadProgression.walletResources(
                        for: featuredDefinition,
                        homestead: homesteadState,
                        roster: rosterState
                    )
                )

                if let featuredDefinition {
                    HomesteadFeaturedProjectCard(
                        definition: featuredDefinition,
                        status: HomesteadProjectStatus(
                            definition: featuredDefinition,
                            homestead: homesteadState,
                            roster: rosterState
                        ),
                        onBuild: { buildOrUpgrade(featuredDefinition) }
                    )
                }

                ForEach(HomesteadNodeCategory.allCases) { category in
                    let definitions = definitions(in: category)
                    if !definitions.isEmpty {
                        HomesteadProjectSection(
                            category: category,
                            definitions: definitions,
                            homestead: homesteadState,
                            roster: rosterState,
                            recentUpgradeID: recentUpgradeID
                        )
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 112)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Homestead")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier(AccessibilityID.Screen.homestead)
        .sensoryFeedback(.success, trigger: upgradeEventCount)
    }

    private func buildOrUpgrade(_ definition: HomesteadNodeDefinition) {
        guard appState.homestead.buildOrUpgrade(definition, roster: appState.roster) else { return }
        recentUpgradeID = definition.id
        upgradeEventCount += 1

        guard !reduceMotion else { return }
        withAnimation(.snappy) {
            recentUpgradeID = definition.id
        }
    }

    private func definitions(in category: HomesteadNodeCategory) -> [HomesteadNodeDefinition] {
        HomesteadProgression.visibleDefinitions(
            in: category,
            all: allDefinitions,
            homestead: homesteadState
        )
    }
}
