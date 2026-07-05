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
        .alert(
            "Build Failed",
            isPresented: Binding(
                get: { homesteadBuildError != nil },
                set: { if !$0 { homesteadBuildError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(homesteadBuildError ?? "")
        }
    }

    private func buildOrUpgrade(_ definition: HomesteadNodeDefinition) {
        switch appState.homestead.buildOrUpgrade(definition, roster: appState.roster) {
        case .success:
            recentUpgradeID = definition.id
            upgradeEventCount += 1
            guard !reduceMotion else { return }
            withAnimation(.snappy) {
                recentUpgradeID = definition.id
            }
        case .insufficientResources:
            homesteadBuildError = "Not enough resources to build or upgrade this project."
        case .persistFailed:
            homesteadBuildError = "Couldn't save homestead progress. Try again."
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
