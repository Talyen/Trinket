import SwiftUI
import TrinketContent
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HomesteadResourceWallet(
                    homestead: homesteadState,
                    roster: rosterState
                )

                ForEach(HomesteadNodeCategory.allCases) { category in
                    let definitions = definitions(in: category)
                    if !definitions.isEmpty {
                        HomesteadProjectShelf(
                            category: category,
                            definitions: definitions,
                            homestead: homesteadState,
                            roster: rosterState,
                            recentUpgradeID: recentUpgradeID,
                            onBuild: buildOrUpgrade
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
        GameContent.homesteadNodes.filter { $0.category == category }
    }
}
